#!/bin/bash
#
# Script to check cpu load

# number of cores assigned to the pilot
pilot_cores=$1

/usr/bin/uptime
#cpu load of last minute
#cpu_load=$(/usr/bin/uptime | awk '{print $11}' | sed 's/,/ /g')
cpu_load=$(/usr/bin/uptime | grep -ohe 'load average[s:][: ].*' | awk -F'[, ]' '{ print $3}')

#number of cpus
echo "Number of physical CPUs"
grep -c ^processor /proc/cpuinfo
physical_cpus=$(grep -c ^processor /proc/cpuinfo)

echo $cpu_load
if [[ $(echo "$cpu_load >= $physical_cpus" | bc) -eq 1 ]]; then
  echo "${ERROR_CPU_LOAD_MSG}, physical_cpus: ${physical_cpus}, cpu_load: ${cpu_load}"
  # return $ERROR_CPU_LOAD
elif [[ $(echo "$(echo $cpu_load + $pilot_cores | bc) >= $physical_cpus" | bc) -eq 1 ]]; then
  echo $WARNING_CPU_LOAD_MSG
  metrics+=" status WARNING"
  metrics+=" warning_code ${WARNING_CPU_LOAD}"
  # return $WARNING_CPU_LOAD
fi
