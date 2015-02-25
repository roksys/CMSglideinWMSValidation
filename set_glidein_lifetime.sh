#!/bin/sh
# glideinWMS script to re-set the GLIDEIN_ToRetire time for entries at PIC
# UNTESTED!
# J. Letts, February 25, 2015

# Set up to use scripts to change the glidein configuration
# Ref: http://www.uscms.org/SoftwareComputing/Grid/WMS/glideinWMS/doc.prd/factory/custom_scripts.html
glidein_config="$1"
add_config_line_source=`awk '/^ADD_CONFIG_LINE_SOURCE /{print $2}' $glidein_config`
source $add_config_line_source
condor_vars_file=`grep -i "^CONDOR_VARS_FILE " $glidein_config | awk '{print $2}'`

# Only at PIC, else exit 0
glidein_CMSSite=`grep "^GLIDEIN_CMSSite " $glidein_config | awk '{print $2}'`
if [ glidein_CMSSite != 'T1_ES_PIC' ] ; then
  exit 0
fi

# Set the retire time by entry at PIC for the multi-core entries, else exit 0
glidein_Entry_Name=`grep "^GLIDEIN_Entry_Name " $glidein_config | awk '{print $2}'`
Now=`/bin/date +%s`
if [ glidein_Entry_Name=="CMSHTPC_T1_ES_PIC_ce07-multicore" ] ; then
  retire_time=$[$Now+(8*3600)]
elif [ glidein_Entry_Name=="CMSHTPC_T1_ES_PIC_ce08-multicore" ] ; then
  retire_time=$[$Now+(12*3600)]
else
  exit 0
fi

# sanity check to make sure we are setting the retire time to be shorter, not longer
previous_retire_time=`grep "^GLIDEIN_ToRetire " $glidein_config | awk '{print $2}'`
if [ $retire_time -gt $previous_retire_time ] ; then
  echo "ERROR: New GLIDEIN_ToRetire ${retire_time} is greater that the previous value ${previous_retire_time}."
  exit 1
fi

# Export to glidein and condor configurations
add_config_line "GLIDEIN_ToRetire" $retire_time
# add_condor_vars_line myattribute type def condor_name req publish jobid
add_condor_vars_line "GLIDEIN_ToRetire" "I" "-" "+" "Y" "Y" "-"

exit 0
