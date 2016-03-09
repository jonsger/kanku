#!/bin/bash

REST_URL="http://localhost:5000/rest"

case $1 in 
  obs-server) 
    DATA='args={"Kanku::Handler::OBSDownload":{"skip_all_checks":1}}'
  ;;
  sles11sp3)
    DATA=''
  ;;
  *)
    print "Usage: "`basename $0`"<obs-server|sles11sp3>"
  ;;
esac

curl -d  "$DATA" $REST_URL/job/trigger/$1\.json
