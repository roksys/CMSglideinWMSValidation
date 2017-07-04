#!/bin/bash
#
# Script to test connectivity and check clock for skew

client_timestamp_sent=$(date +%s)
# -s - Avoid showing progress bar
# -D - - Dump headers to a file, but - sends it to stdout
# -o /dev/null - Ignore response body
header=$(curl --connect-timeout 5 -sD - -o /dev/null https://google.com)
rc=$?
client_timestamp_received=$(date +%s)
if [ "$rc" -eq 0 ]; then
  server_time=$(echo "$header" | sed -n 's/.*Date: //p')
  server_timestamp=$(date --date="${server_time}" +%s)
  round_trip_time=$((client_timestamp_received-client_timestamp_sent))
  echo "Online"
  echo "Client timestamp sent" $client_timestamp_sent
  echo "Server timestamp" $server_timestamp
  echo "Client timestamp received "$client_timestamp_received
  echo "Round trip time:" $round_trip_time
  one_way_trip=$((round_trip_time / 2))
  time_difference=$((client_timestamp_sent + one_way_trip - server_timestamp))
  if [ "$time_difference" -ge -5 -a "$time_difference" -le 5 ]; then
    echo "Clock skew is not bigger than 5 sec"
  else
    echo $ERROR_CLOCK_SKEW_MSG
    exit $ERROR_CLOCK_SKEW
  fi
else
  /usr/bin/nc -zv -w 15 dashb-mb.cern.ch 61113
  if [ $? -eq 0 ]; then
    echo "Online"
    exit 0
  else
    echo $ERROR_NO_CONNECTION_MSG
    exit $ERROR_NO_CONNECTION
  fi
fi
