#!/usr/bin/python

import os
import sys
import json
import optparse
import xml.etree.ElementTree

import classad
import htcondor


def get_siteconf_path():
    if 'VO_CMS_SW_DIR' in os.environ:
        siteconf_path = os.path.join(os.environ['VO_CMS_SW_DIR'], "SITECONF")
    else:
        cvmfs_path = os.environ.get("CVMFS", "/cvmfs")
        siteconf_path = os.path.join(cvmfs_path, "cms.cern.ch", "SITECONF")
    return siteconf_path


def parse_opts():
    parser = optparse.OptionParser()
    parser.add_option("-p", "--pool", default="cmsgwms-collector-global.cern.ch", help="HTCondor pool to query", dest="pool")
    parser.add_option("-s", "--site", help="Local site name (defaults to site configured in CVMFS)", dest="site")
    parser.add_option("-l", "--local-users", help="Location of local-users.txt", default="/cvmfs/cms.cern.ch/SITECONF/local/GlideinConfig/local-users.txt", dest="local_users")
    parser.add_option("-c", "--const", help="Schedd query constraint", default='CMSGWMS_Type =?= "crabschedd"', dest="const");
    parser.add_option("-j", "--jobs-only", help="Query jobs instead of autoclusters", default=False, action="store_true")
    parser.add_option("-q", "--quiet", help="Reduce output verbosity", default=False, action="store_true")

    opts, args = parser.parse_args()

    if not opts.site:
        local_siteconf = os.path.join(get_siteconf_path(), "local")
        if not os.path.exists(local_siteconf):
            print >> sys.stderr, "CVMFS siteconf path (%s) does not exist; is CVMFS running and configured properly?" % local_siteconf
            sys.exit(1)
        job_config = os.path.join(local_siteconf, "JobConfig", "site-local-config.xml")
        if not os.path.exists(job_config):
            print "site-local-config.xml does not exist in CVMFS (looked at %s); is CVMFS running and configured properly?" % job_config

        tree = xml.etree.ElementTree.parse(job_config)
        job_config_root = tree.getroot()

        site_name = None
        if job_config_root[0].get('name'):
            site_name = job_config_root[0].get('name')
        if not site_name:
            print >> sys.stderr, "Unable to determine site name."
            sys.exit(1)
        opts.site = site_name

    if opts.const:
        try:
            opts.const = classad.ExprTree(opts.const)
        except:
            print >> sys.stderr, "Unable to parse constraint into a valid expression: %s" % opts.const
            sys.exit(1)

    try:
        open(opts.local_users, "r").close()
    except IOError, ie:
        print >> sys.stderr, "Unable to open local users file: %s" % opts.local_users
        print >> sys.stderr, str(ie)
        sys.exit(1)

    if opts.pool:
        opts.pool = opts.pool.split(",")

    return opts


def main():
    opts = parse_opts()

    users = set()
    for line in open(opts.local_users):
        line = line.strip()
        if line.startswith("#"): continue
        users.add(line)

    collectors = set()
    for pool in opts.pool:
        coll = htcondor.Collector(pool)
        collectors.add(coll)
        if not opts.quiet: print >> sys.stderr, "Querying collector %s for schedds matching" % pool, opts.const

    reqs = '(JobStatus == 1) && stringListMember(%s, DESIRED_Sites)' % classad.quote(opts.site)
    idle_count = {}
    for user in users:
        if user == "*": continue
        idle_count.setdefault(user, 0)
    user_map = {}
    if not opts.quiet: print >> sys.stderr, "Schedd job requirements:", reqs
    for coll in collectors:
        for schedd_ad in coll.query(htcondor.AdTypes.Schedd, opts.const, ['MyAddress', 'CondorVersion', 'Name', 'ScheddIpAddr']):
            if not opts.quiet: print >> sys.stderr, "Querying", schedd_ad.get('Name', "Unknown")
            schedd = htcondor.Schedd(schedd_ad)
            try:
                if opts.jobs_only:
                    schedd_data = schedd.xquery(requirements=reqs, projection=["x509userproxysubject", "CRAB_UserHN", "JobStatus"])
                else:
                    schedd_data = schedd.xquery(requirements=reqs, projection=["x509userproxysubject", "CRAB_UserHN", "JobStatus"], opts=htcondor.QueryOpts.AutoCluster)
            except RuntimeError, e:
                if not opts.quiet: print >> sys.stderr, "Error querying %s: %s" % (schedd_ad.get('Name', "Unknown"), e)
            if not opts.jobs_only:
                for cluster in schedd_data:
                    user = cluster.get("CRAB_UserHN")
                    if (user in users) or ("*" in users):
                        idle_count.setdefault(user, 0)
                        idle_count[user] += int(cluster.get("JobCount", 0))
                        if 'x509userproxysubject' in cluster:
                            user_map[user] = cluster['x509userproxysubject']
            if opts.jobs_only:
                for job in schedd_data:
                    user = job.get("CRAB_UserHN")
                    if (user in users) or ("*" in users):
                        idle_count.setdefault(user, 0)
                        idle_count[user] += 1
                        if 'x509userproxysubject' in job:
                            user_map[user] = job['x509userproxysubject']
    results = {'users': user_map, 'idle': idle_count}
    print json.dumps(results)

if __name__ == "__main__":
    main()

