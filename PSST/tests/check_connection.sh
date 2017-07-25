#!/bin/bash
#
# Script to test connectivity and check clock for skew


check_connecction() {
  endpoint="$1"
  echo "Trying to get http header of ${endpoint}"
  client_timestamp_sent=$(date +%s)
  # Fetch the HTTP-header only!
  # -s - Avoid showing progress bar
  # -4 IPv4
  # -k allow insecure connections
  header=$(curl -4 -k --connect-timeout 5 --head -s https://${endpoint})
  rc=$?
  echo "exit code: " $rc
  client_timestamp_received=$(date +%s)
  if [ "$rc" -eq 0 ]; then
    echo "$header" | sed 's/\&//g' # removing illegal char & for xml
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
    if [ "$time_difference" -ge -60 -a "$time_difference" -le 60 ]; then
      echo "Clock skew is not bigger than 60 sec"
      echo "Test was passed, exiting"
      exit 0
    else
      echo $ERROR_CLOCK_SKEW_MSG
      return $ERROR_CLOCK_SKEW
    fi
  else
    echo "Failed to get http header of ${endpoint}"
    echo $ERROR_NO_CONNECTION_MSG
    return $ERROR_NO_CONNECTION
    # if [ -f /usr/bin/nc ]; then
    #   /usr/bin/nc -zv -w 15 dashb-mb.cern.ch 61113
    #   if [ $? -eq 0 ]; then
    #     echo "Online"
    #     exit 0
    #   else
    #     echo $ERROR_NO_CONNECTION_MSG
    #     return $ERROR_NO_CONNECTION
    #   fi
    # else
    #   echo "Can't check connectivity. CURL failed, nc does not exist"
    #   return 0
    # fi
  fi
}

endpoints="google.com cern.ch"
for hostname in $endpoints
do
  check_connecction $hostname
  exit_code=$?
done
exit $exit_code
