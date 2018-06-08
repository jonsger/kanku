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
use Log::Log4perl;
use Const::Fast;
use Carp;

const my $MTIME_POS => 9;
const my $FILE_LENGTH_POS => 7;
const my $FILE_MODE_RW_ALL => '0777';

sub mirror
{
    my($self, %opt) = @_;
    my $logger      = Log::Log4perl->get_logger();
    my $url         = $opt{url};
    my $file        = $opt{file};
    my $etag        = $opt{etag};

    my $request = $opt{request} || HTTP::Request->new('GET', $url);

    $self->prepare_cache_related_headers($request, %opt);

    my $tmpfile = "$file-$$";

    my $response = $self->request($request, $tmpfile);
    croak($response->header('X-Died')) if $response->header('X-Died');

    # Only fetching a fresh copy of the would be considered success.
    # If the file was not modified, "304" would returned, which
    # is considered by HTTP::Status to be a "redirect", /not/ "success"
    if ( $response->is_success ) {
        my @stat        = stat $tmpfile or croak("Could not stat tmpfile '$tmpfile': $!");
        my $file_length = $stat[$FILE_LENGTH_POS];
        my ($content_length) = $response->header('Content-length');

        if ( defined $content_length and $file_length < $content_length ) {
            unlink $tmpfile || croak("Could not unlink $tmpfile: $!\n");
            croak("Transfer truncated: only $file_length out of $content_length bytes received\n");
        }
        elsif ( defined $content_length and $file_length > $content_length ) {
            unlink $tmpfile || croak("Could not unlink $tmpfile: $!\n");
            croak("Content-length mismatch: expected $content_length bytes, got $file_length\n");
        }
        # The file was the expected length.
        else {
            # Replace the stale file with a fresh copy
            if ( -e $file ) {
                # Some DOSish systems fail to rename if the target exists
                chmod $FILE_MODE_RW_ALL, $file
		  || croak("Cannot change mode for '$file': $!\n");
                unlink $file || croak("Could not unlink $file: $!\n");
            }
            rename $tmpfile, $file
                or croak("Cannot rename '$tmpfile' to '$file': $!\n");

            # make sure the file has the same last modification time
            if ( my $lm = $response->last_modified ) {
                utime $lm, $lm, $file || croak("Cannot set utime for '$file': $!\n");
            }
        }
    }
    # The local copy is fresh enough, so just delete the temp file
    else {
        unlink $tmpfile || croak("Could not unlink $tmpfile: $!\n");
    }
    return $response;
}

sub prepare_cache_related_headers {
    my ($self, $request, %opt) = @_;
    my $logger      = Log::Log4perl->get_logger();
    my $file        = $opt{file};
    my $etag        = $opt{etag};

    # If the file exists, add a cache-related header
    if ( -e $file ) {
        $logger->debug('Output file exists!');
        my ($mtime)   = ( stat $file )[$MTIME_POS];
        if ($etag) {
          $logger->debug(" - found etag, adding 'If-None-Match: $etag'");
          $request->header('If-None-Match' => $etag);
          $self->default_header('If-None-Match' => $etag);
        } elsif ($mtime) {
          my $http_date = HTTP::Date::time2str($mtime);
          $logger->debug(" - got mtime, adding 'If-Modified-Since: $http_date' ($mtime)");
          $request->header('If-Modified-Since' => $http_date);
          $self->default_header('If-Modified-Since' => $http_date);
        }
    }

    return;
}

1;
