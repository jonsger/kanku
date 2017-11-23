#!/bin/bash

BASEDIR=`dirname $0`

SRCDIR=$BASEDIR/../public/images/196

for pic in `ls $SRCDIR/|grep -P '\.png$'`;do
  for dir in 32 48 64;do
    src=$SRCDIR/$pic
    dst=$BASEDIR/../public/images/$dir/$pic
    if [ -f $dst ];then
      echo "Skipping $src. $dst alread exists!"
    else
      echo "Converting $src -> $dst"
      convert $src -scale ${dir}x${dir} $dst
    fi
  done
done
