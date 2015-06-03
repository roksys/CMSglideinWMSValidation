# CMSglideinWMSValidation
Validation scripts for CMS glideins

# CMSLPCMapper

In order to use the LPC mapper, you want to add the following line to the configuration:

JOB_ROUTER.CLASSAD_USER_PYTHON_MODULES = $(CLASSAD_USER_PYTHON_MODULES), CMSLPCMapper

By default, it will read from the URL specified by the HTCondor config knob CMSLPC_USER_URL.

If that is not set (or an error occurs), it will read from CMSLPC_USER_CACHE.  CMSLPC_USER_CACHE
defaults to $(SPOOL)/cmslpc_cache.txt

