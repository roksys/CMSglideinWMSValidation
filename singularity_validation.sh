#!/bin/sh

glidein_config="$1"

function info {
    echo "INFO  " $@ 1>&2
}

function warn {
    echo "WARN  " $@ 1>&2
}

function advertise {
    # atype is the type of the value as defined by GlideinWMS:
    #   I - integer
    #   S - quoted string
    #   C - unquoted string (i.e. Condor keyword or expression)
    key="$1"
    value="$2"
    atype="$3"

    if [ "$glidein_config" != "NONE" ]; then
        add_config_line $key "$value"
        add_condor_vars_line $key "$atype" "-" "+" "Y" "Y" "+"
    fi

    if [ "$atype" = "S" ]; then
        echo "$key = \"$value\""
    else
        echo "$key = $value"
    fi
}


if [ "x$glidein_config" = "x" ]; then
    glidein_config="NONE"
    info "No arguments provided - assuming HTCondor startd cron mode"
else
    info "Arguments to the script: $@"
fi

info "This is a setup script for the CMS frontend."
info "In case of problems, contact CMS support at ggus.eu"
info "Running in directory $PWD"

if [ "$glidein_config" != "NONE" ]; then
    ###########################################################
    # import advertise and add_condor_vars_line functions
    # are we inside singularity?
    if [ "x$add_config_line_source" = "x" ]; then
        export add_config_line_source=`grep '^ADD_CONFIG_LINE_SOURCE ' $glidein_config | awk '{print $2}'`
        export condor_vars_file=`grep -i "^CONDOR_VARS_FILE " $glidein_config | awk '{print $2}'`
    fi

    source $add_config_line_source
fi


###########################################################
# attributes below this line

##################
# cvmfs filesystem availability this has to come before singularity checks

if [ "x$OSG_SINGULARITY_REEXEC" = "x" ]; then
    info "Checking for CVMFS availability and attributes..."
    for FS in \
       cms.cern.ch \
       oasis.opensciencegrid.org \
       singularity.opensciencegrid.org \
    ; do
        FS_CONV=`echo "$FS" | sed 's/\./_/g'`
        FS_ATTR="HAS_CVMFS_$FS_CONV"
        RESULT="False"
        if [ -e /cvmfs/$FS/. ]; then
            RESULT="True"
            # add the revision
            REV_ATTR="CVMFS_${FS_CONV}_REVISION"
            REV_VAL=`/usr/bin/attr -q -g revision /cvmfs/$FS/. 2>/dev/null`
            if [ "x$REV_VAL" != "x" ]; then
                # make sure it is an integer
                if [ "$REV_VAL" -eq "$REV_VAL" ] 2>/dev/null; then
                    advertise $FS_ATTR "$RESULT" "C"
                    advertise $REV_ATTR "$REV_VAL" "I"
                fi
            else
                # unable to determine revision - this is common on sites which re-export CVMFS
                # via for example NFS locally. Advertise availability.
                advertise $FS_ATTR "$RESULT" "C"
            fi
        fi
    done
    
    # update timestamp?
    TS_ATTR="CVMFS_oasis_opensciencegrid_org_TIMESTAMP"
    TS_VAL=`(cat /cvmfs/oasis.opensciencegrid.org/osg/update.details  | egrep '^Update unix time:' | sed 's/.*: //') 2>/dev/null`
    if [ "x$TS_VAL" != "x" ]; then
        # make sure it is an integer
        if [ "$TS_VAL" -eq "$TS_VAL" ] 2>/dev/null; then
            advertise $TS_ATTR "$TS_VAL" "I"
        fi
    fi

fi # OSG_SINGULARITY_REEXEC

##################
# singularity
# advertise availability and version

if [ "x$OSG_SINGULARITY_REEXEC" = "x" ]; then
    info "Checking for singularity..."

    # some known singularity locations
    for LOCATION in \
        /util/opt/singularity/2.2.1/gcc/4.4/bin \
        /util/opt/singularity/2.2/gcc/4.4/bin \
        /uufs/chpc.utah.edu/sys/installdir/singularity/std/bin \
    ; do
        if [ -e "$LOCATION" ]; then
            info " ... prepending $LOCATION to PATH"
            export PATH="$LOCATION:$PATH"
            break
        fi
    done

    HAS_SINGULARITY="False"
    export OSG_SINGULARITY_VERSION=`singularity --version 2>/dev/null`
    if [ "x$OSG_SINGULARITY_VERSION" != "x" ]; then
        HAS_SINGULARITY="True"
        export OSG_SINGULARITY_PATH=`which singularity`
    else
        # some sites requires us to do a module load first - not sure if we always want to do that
        export OSG_SINGULARITY_VERSION=`module load singularity >/dev/null 2>&1; singularity --version 2>/dev/null`
        if [ "x$OSG_SINGULARITY_VERSION" != "x" ]; then
            HAS_SINGULARITY="True"
            export OSG_SINGULARITY_PATH=`module load singularity >/dev/null 2>&1; which singularity`
        fi
    fi

    # default image for this glidein
    export OSG_SINGULARITY_IMAGE_DEFAULT="/cvmfs/singularity.opensciencegrid.org/opensciencegrid/osg-wn:3.3-el6"

    # for now, we will only advertise singularity on nodes which can access cvmfs
    if [ ! -e "$OSG_SINGULARITY_IMAGE_DEFAULT" ]; then
        HAS_SINGULARITY="False"
    fi

    # workaround for user nobody with HOME=/
    if [ "x$USER" = "x" ]; then
        export USER=`whoami 2>/dev/null`
    fi
    EXTRA_ARGS=""
    if [ "x$USER" = "xnobody" ]; then
        EXTRA_ARGS=" --home $PWD:/srv"
    fi

    # Let's do a simple singularity test by echoing something inside, and then
    # grepping for it outside. This takes care of some errors which happen "late"
    # in the execing, like:
    # ERROR  : Could not identify basedir for home directory path: /
    if [ "x$HAS_SINGULARITY" = "xTrue" ]; then
        info "$OSG_SINGULARITY_PATH exec $EXTRA_ARGS --bind /cvmfs --bind $PWD:/srv --pwd /srv --scratch /var/tmp --scratch /tmp --containall $OSG_SINGULARITY_IMAGE_DEFAULT echo Hello World | grep Hello World"
        if ! ($OSG_SINGULARITY_PATH exec $EXTRA_ARGS \
                                         --bind /cvmfs \
                                         --bind $PWD:/srv \
                                         --pwd /srv \
                                         --scratch /var/tmp \
                                         --scratch /tmp \
                                         --containall \
                                         "$OSG_SINGULARITY_IMAGE_DEFAULT" \
                                         echo "Hello World" \
                                         | grep "Hello World") 1>&2 \
        ; then
            # singularity simple exec failed - we are done
            info "Singularity simple exec failed.  Disabling support"
            HAS_SINGULARITY="False"
        fi
    fi

    # Let's now check for SITECONF presence.
    if [ "x$HAS_SINGULARITY" = "xTrue" ]; then

        # Various possible mount points to pull into the container:
        for VAR in /etc/cvmfs/SITECONF; do
            if [ -e "$VAR" -a -e "$OSG_SINGULARITY_IMAGE_DEFAULT/$VAR" ]; then
                EXTRA_ARGS="$EXTRA_ARGS --bind $VAR"
            fi
        done

        info "Checking for SITECONF/local"
        info "$OSG_SINGULARITY_PATH exec $EXTRA_ARGS --bind /cvmfs --bind $PWD:/srv --pwd /srv --scratch /var/tmp --scratch /tmp --containall $OSG_SINGULARITY_IMAGE_DEFAULT echo Hello World | grep Hello World"
        if ! ($OSG_SINGULARITY_PATH exec $EXTRA_ARGS \
                                         --bind /cvmfs \
                                         --bind $PWD:/srv \
                                         --pwd /srv \
                                         --scratch /var/tmp \
                                         --scratch /tmp \
                                         --containall \
                                         "$OSG_SINGULARITY_IMAGE_DEFAULT" \
                                         /bin/sh -c '[ -e /cvmfs/cms.cern.ch/SITECONF/local/ ]' \
                                         ) 1>&2 \
        ; then
            # singularity simple exec failed - we are done
            info "SITECONF is not present inside Singularity container.  Disabling support"
            HAS_SINGULARITY="False"
        fi
    fi

    # If we still think we have singularity, we should re-exec this script within the default
    # container so that we can advertise that environment
    if [ "x$HAS_SINGULARITY" = "xTrue" ]; then
        # We want to map the full glidein dir to /srv inside the container. This is so 
        # that we can rewrite env vars pointing to somewhere inside that dir (for
        # example, X509_USER_PROXY)
        export SING_OUTSIDE_BASE_DIR=`echo "$PWD" | sed -E "s;(.*/glide_[a-zA-Z0-9]+).*;\1;"`

        # build a new command line, with updated paths
        CMD=""
        for VAR in $0 "$@"; do
            VAR=`echo " $VAR" | sed -E "s;.*/glide_[a-zA-Z0-9]+(.*);/srv\1;"`
            CMD="$CMD $VAR"
        done
    
        # workaround for user nobody with HOME=/
        EXTRA_ARGS=""
        if [ "x$USER" = "xnobody" ]; then
            EXTRA_ARGS=" --home $SING_OUTSIDE_BASE_DIR:/srv"
        fi

        # Various possible mount points to pull into the container:
        for VAR in /cms /hadoop /hdfs /mnt/hadoop /etc/cvmfs/SITECONF; do
            if [ -e "$VAR" ]; then
                EXTRA_ARGS="$EXTRA_ARGS --bind $VAR"
            fi
        done

        # Update the location of the advertise script:
        add_config_line_source=`echo "$add_config_line_source" | sed -E "s;.*/glide_[a-zA-Z0-9]+(.*);/srv\1;"`
        condor_vars_file=`echo "$condor_vars_file" | sed -E "s;.*/glide_[a-zA-Z0-9]+(.*);/srv\1;"`

        # let "inside" script know we are re-execing
        export OSG_SINGULARITY_REEXEC=1
        info "$OSG_SINGULARITY_PATH exec $EXTRA_ARGS --bind /cvmfs --bind $SING_OUTSIDE_BASE_DIR:/srv --pwd /srv --scratch /var/tmp --scratch /tmp --containall $OSG_SINGULARITY_IMAGE_DEFAULT $CMD"
        if $OSG_SINGULARITY_PATH exec $EXTRA_ARGS \
                                      --bind /cvmfs \
                                      --bind $SING_OUTSIDE_BASE_DIR:/srv \
                                      --pwd /srv \
                                      --scratch /var/tmp \
                                      --scratch /tmp \
                                      --containall \
                                      "$OSG_SINGULARITY_IMAGE_DEFAULT" \
                                      $CMD \
        ; then
            # singularity worked - exit here as the rest script ran inside the container
            exit $?
        fi
    fi
    
    # if we get here, singularity is not available or not working
    advertise HAS_SINGULARITY "False" "C"
    exit 0
fi


info "Already running inside singularity"

# fix up the env
for key in X509_USER_PROXY X509_USER_CERT _CONDOR_MACHINE_AD _CONDOR_JOB_AD \
               _CONDOR_SCRATCH_DIR _CONDOR_CHIRP_CONFIG _CONDOR_JOB_IWD \
               add_config_line_source condor_vars_file ; do
    eval val="\$$key"
    val=`echo "$val" | sed -E "s;$SING_OUTSIDE_BASE_DIR(.*);/srv\1;"`
    eval $key=$val
done

# Any further tests that require Singularity should go here.


# At this point, we're convinced Singularity works
advertise HAS_SINGULARITY "True" "C"
advertise OSG_SINGULARITY_VERSION "$OSG_SINGULARITY_VERSION" "S"
advertise OSG_SINGULARITY_PATH "$OSG_SINGULARITY_PATH" "S"
advertise OSG_SINGULARITY_IMAGE_DEFAULT "$OSG_SINGULARITY_IMAGE_DEFAULT" "S"
advertise GLIDEIN_REQUIRED_OS "any" "S"

# Disable glexec if we are going to use Singularity.
advertise GLEXEC_JOB "False" "C"
advertise GLEXEC_BIN "NONE" "C"

