#!/bin/bash
#

BASEDIR=`dirname $PWD/$0`"/.."

echo $BASEDIR

ALL_MODULES=( `find $BASEDIR/lib -name *.pm` )

ALL_BINS=(kanku kanku-scheduler kanku-triggerd kanku-dispatcher kanku-worker)
TEST_COUNTER=0

echo "1.."$(( ${#ALL_MODULES[@]}  + ${#ALL_BINS[@]}))

for i in `seq 0 $(( ${#ALL_BINS[@]} - 1 )) `;do
  TEST_COUNTER=$(( TEST_COUNTER + 1 )) 
  bin=${ALL_BINS[$i]}
  perl -I$BASEDIR/lib -c $BASEDIR/bin/$bin 2>/dev/null

  if [[ $? == 0 ]];then
    echo -n "ok "
  else 
    echo -n "not ok "
  fi

  echo $TEST_COUNTER" - Checking bin $bin"
done




for i in `seq 0 $(( ${#ALL_MODULES[@]} - 1 )) `;do
  MODULE_FILE=${ALL_MODULES[$i]}
  MODULE_NAME=`echo $MODULE_FILE|perl -p -e 's#.*/(lib/Kanku(/.+)?.pm)$#$1#'`
  TEST_COUNTER=$(( TEST_COUNTER + 1 )) 
  bin=${ALL_BINS[$i]}
  
  perl -I$BASEDIR/lib -c $MODULE_FILE 2>/dev/null

  if [[ $? == 0 ]];then
    echo -n "ok "
  else 
    echo -n "not ok "
  fi

  echo $TEST_COUNTER" - Checking use of $MODULE_NAME"
  
done
