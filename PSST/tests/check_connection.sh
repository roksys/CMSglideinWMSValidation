#!/bin/bash
#
# Script to test connectivity

# -z just scan for listening daemons, without sending any data to them.
# -v more verbose output
# -w timeout
/usr/bin/nc -zv -w 5 dashb-mb.cern.ch 61113
if [ $? -eq 0 ]; then
  echo "Online"
  exit 0
fi

/usr/bin/nc -zv -w 5 google.com 80
if [ $? -ne 0 ]; then
  echo "Online"
else
  echo $ERROR_NO_CONNECTION_MSG
  exit $ERROR_NO_CONNECTION
fi
