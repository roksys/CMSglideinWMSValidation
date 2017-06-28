#!/bin/bash

# set return code behaviour for squid/frontier test:
# export SAME_OK=0
# export SAME_WARNING=0
# export SAME_ERROR=1

# set up interface to condor:
glidein_config="$1"
my_tar_dir="$2"
#condor_vars_file=`awk '/^CONDOR_VARS_FILE /{print $2}' $glidein_config`
#add_config_line_source=`awk '/^ADD_CONFIG_LINE_SOURCE /{print $2}' $glidein_config`
#source $add_config_line_source

PARROT_RUN_WORKS=`grep -i "^PARROT_RUN_WORKS " $glidein_config | awk '{print $2}'`

# big fix for glideinWMS:
function warn {
  echo `date` $@ 1>&2
}

# set up CMSSW environment; CMS_PATH needed for squid/frontier test:
if [ -f "$CVMFS/cms.cern.ch/cmsset_default.sh" ]; then
  echo "Found CMS SW in $CVMFS/cms.cern.ch" 1>&2
  source "$CVMFS/cms.cern.ch/cmsset_default.sh"
elif [ -f "/cvmfs/cms.cern.ch/cmsset_default.sh" ]; then
  echo "Found CMS SW in /cvmfs/cms.cern.ch" 1>&2
  source "/cvmfs/cms.cern.ch/cmsset_default.sh"
elif [ -f "$VO_CMS_SW_DIR/cmsset_default.sh" ]; then
  echo "Found CMS SW in $VO_CMS_SW_DIR" 1>&2
  source "$VO_CMS_SW_DIR/cmsset_default.sh"
elif [ -f "$OSG_APP/cmssoft/cms/cmsset_default.sh" ]; then
  echo "Found CMS SW in $OSG_APP/cmssoft/cms" 1>&2
  source "$OSG_APP/cmssoft/cms/cmsset_default.sh"
elif [ "X$PARROT_RUN_WORKS" = "XTRUE" ]; then
   echo "Pilot will use parrot; this already checked for squid functionality." 1>&2
   exit 0
else
  echo "cmsset_default.sh not found!\n" 1>&2
  echo "Looked in$CVMFS/cms.cern.ch/cmsset_default.sh" 1>&2
  echo "and /cvmfs/cms.cern.ch/cmsset_default.sh" 1>&2
  echo "and $VO_CMS_SW_DIR/cmsset_default.sh" 1>&2
  echo "and $OSG_APP/cmssoft/cms/cmsset_default.sh" 1>&2
  echo "and \$PARROT_RUN_WORKS is set to $PARROT_RUN_WORKS" 1>&2
  exit 1
fi

# Find and execute the squid/frontier test for CMS
#my_tar_dir=`grep -i '^GLIDECLIENT_CMS_TEST_SQUID ' $glidein_config | awk '{print $2}'`
${my_tar_dir}/tests/test_squid.py
RC=$?
if [ "$RC" = 40 ]; then
  metrics+=" status WARNING"
fi

#add_config_line "CMS_VALIDATION_FRONTIER" $RC
#add_condor_vars_line "CMS_VALIDATION_FRONTIER" "S" "-" "+" "N" "Y" "+"
return $RC
