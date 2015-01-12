#!/bin/bash
glidein_config="$1"
add_config_line_source=`awk '/^ADD_CONFIG_LINE_SOURCE /{print $2}' $glidein_config`
source $add_config_line_source

condor_vars_file=`grep -i "^CONDOR_VARS_FILE " $glidein_config | awk '{print $2}'`

# expr does not seem to get to the WN - probably a glideinWMS bug
add_config_line "CMS_HOLD_MEMORY" "((ResidentSetSize=!=undefined)&&(ResidentSetSize>4000000))"
add_config_line "CMS_HOLDREASON_MEMORY" "Memory of 4G as per CMS rules exceeded"
add_config_line "CMS_HOLD_DISK" "((DiskUsage=!=undefined)&&(DiskUsage>80000000))"
add_config_line "CMS_HOLDREASON_DISK" "Disk of 80G as per CMS rules exceeded"
add_config_line "WANT_HOLD" '(($(CMS_HOLD_MEMORY))||($(CMS_HOLD_DISK)))'
add_config_line "WANT_HOLD_REASON" 'ifThenElse($(CMS_HOLD_MEMORY),$(CMS_HOLDREASON_MEMORY),ifThenElse($(CMS_HOLD_DISK),$(CMS_HOLDREASON_DISK),undefined))'
add_config_line "PREEMPT" '$(WANT_HOLD)'
add_config_line "WANT_SUSPEND" "False"
add_config_line "WANT_SUSPEND_VANILLA" "False"
add_config_line "WANT_VACATE" "True"
add_config_line "PREEMPT_GRACE_TIME" '10000000*(($(PREEMPT))=!=True)'
add_condor_vars_line "CMS_HOLD_MEMORY" "C" "-" "+" "Y" "N" "-"
add_condor_vars_line "CMS_HOLDREASON_MEMORY" "S" "-" "+" "Y" "N" "-"
add_condor_vars_line "CMS_HOLD_DISK" "C" "-" "+" "Y" "N" "-"
add_condor_vars_line "CMS_HOLDREASON_DISK" "S" "-" "+" "Y" "N" "-"
add_condor_vars_line "WANT_HOLD" "C" "-" "+" "Y" "N" "-"
add_condor_vars_line "WANT_HOLD_REASON" "C" "-" "+" "Y" "N" "-"
add_condor_vars_line "PREEMPT" "C" "-" "+" "N" "N" "-"
add_condor_vars_line "WANT_SUSPEND" "C" "-" "+" "N" "N" "-"
add_condor_vars_line "WANT_SUSPEND_VANILLA" "C" "-" "+" "N" "N" "-"
add_condor_vars_line "WANT_VACATE" "C" "-" "+" "N" "N" "-"
add_condor_vars_line "PREEMPT_GRACE_TIME" "C" "-" "+" "N" "N" "-"
exit 0
