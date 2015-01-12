#!/bin/sh
# Check that the xrootd fallback is defined in the TFC. If not, we cannot
# overflow jobs to this site.

# big fix for glideinWMS: function not defined in
function warn {
  echo `date` $@ 1>&2
}

# function for ending this validation script
test_result() {
  result=$1
  reason=$2
  echo "CMS xrootd Fallback Validation Result: $reason" 1>&2
  exit $result
}

# set up CMSSW environment
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
else
   echo "cmsset_default.sh not found!\n" 1>&2
   echo "Looked in $CVMFS/cms.cern.ch/cmsset_default.sh" 1>&2
   echo "and /cvmfs/cms.cern.ch/cmsset_default.sh" 1>&2
   echo "and $VO_CMS_SW_DIR/cmsset_default.sh" 1>&2
   echo "and $OSG_APP/cmssoft/cms/cmsset_default.sh" 1>&2
   exit 1
fi

if [ -z $CMS_PATH ] ; then
  warn "CMS_PATH not defined!"
  test_result 1 "CMS_PATHNotDefined"
fi

TFC=${CMS_PATH}/SITECONF/local/PhEDEx/storage.xml
if [ ! -f $TFC ] ; then
  warn "storage.xml not found!"
  test_result 1 "TrivialFileCatalogNotFound"
fi

grep 'lfn-to-pfn protocol="xrootd"' $TFC >>/dev/null 2>&1 || test_result 1 "NoFallbackDefinedInTFC"
test_result 0 "FallbackDefinedInTFC"
