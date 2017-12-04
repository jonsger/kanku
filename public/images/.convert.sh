#!/bin/bash

WD=`dirname $0`

for i in `ls $WD|grep -v 196`
do
  echo $i
  for pic in `ls $WD/196`
  do
    INFILE=$WD/196/$pic
    OUTFILE=$WD/$i/$pic
    SCALE="-scale $i"x"$i"
    convert -verbose $INFILE $SCALE $OUTFILE
  done
done
