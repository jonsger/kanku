#!/bin/bash


RUNNING=`kanku rhistory -l|grep -P "State\s+:\s+(running|dispatching)"`

while [ -n "$RUNNING" ];do
  RUNNING=`kanku rhistory -l|grep -P "State\s+:\s+(running|dispatching)"`
  sleep 10
done

STATE=`kanku rhistory -l|grep -P "State\s+:.*"|perl -p -e 's/^\s*State\s+:\s+(.*)/$1/'`

[ "$STATE" == "succeed" ] && exit 0

exit 1
