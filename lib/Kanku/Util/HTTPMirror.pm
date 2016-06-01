# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Util::HTTPMirror;

use strict;
use warnings;

use base 'LWP::UserAgent';

sub mirror
{
    my($self, %opt) = @_;

    my $url = $opt{url};
    my $file = $opt{file};

    my $request = $opt{request} || HTTP::Request->new('GET', $url);

    # If the file exists, add a cache-related header
    if ( -e $file ) {
        my ($mtime) = ( stat($file) )[9];
        if ($mtime) {
            $request->header( 'If-Modified-Since' => HTTP::Date::time2str($mtime) );
        }
    }
    my $tmpfile = "$file-$$";

    my $response = $self->request($request, $tmpfile);
    if ( $response->header('X-Died') ) {
        die $response->header('X-Died');
    }

    # Only fetching a fresh copy of the would be considered success.
    # If the file was not modified, "304" would returned, which
    # is considered by HTTP::Status to be a "redirect", /not/ "success"
    if ( $response->is_success ) {
        my @stat        = stat($tmpfile) or die "Could not stat tmpfile '$tmpfile': $!";
        my $file_length = $stat[7];
        my ($content_length) = $response->header('Content-length');

        if ( defined $content_length and $file_length < $content_length ) {
            unlink($tmpfile);
            die "Transfer truncated: " . "only $file_length out of $content_length bytes received\n";
        }
        elsif ( defined $content_length and $file_length > $content_length ) {
            unlink($tmpfile);
            die "Content-length mismatch: " . "expected $content_length bytes, got $file_length\n";
        }
        # The file was the expected length.
        else {
            # Replace the stale file with a fresh copy
            if ( -e $file ) {
                # Some DOSish systems fail to rename if the target exists
                chmod 0777, $file;
                unlink $file;
            }
            rename( $tmpfile, $file )
                or die "Cannot rename '$tmpfile' to '$file': $!\n";

            # make sure the file has the same last modification time
            if ( my $lm = $response->last_modified ) {
                utime $lm, $lm, $file;
            }
        }
    }
    # The local copy is fresh enough, so just delete the temp file
    else {
        unlink($tmpfile);
    }
    return $response;
}


1;

