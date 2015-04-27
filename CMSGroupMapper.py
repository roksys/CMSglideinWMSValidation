
import os
import re
import time

g_expire_time = 0
g_cache = {}
g_site_cache = {}

# Set to false to consider 'local' as a valid sitename.
# Useful mostly for testing purposes.
g_ignore_local = True

def cache_users():
    global g_cache

    base_dir = '/cvmfs/cms.cern.ch/SITECONF'
    cache = {}
    user_re = re.compile(r'[-_A-Za-z0-9.]+')
    sites = None
    try:
        if os.path.isdir(base_dir):
            sites = os.listdir(base_dir)
    except:
        pass
    if not sites:
        return
    for entry in sites:
        full_path = os.path.join(base_dir, entry, 'GlideinConfig', 'local-users.txt')
        if g_ignore_local and (entry == 'local'):
            continue
        if not os.path.isfile(full_path):
            continue
        try:
            fd = open(full_path)
            for line in fd:
                line = line.strip()
                if user_re.match(line):
                    group_set = cache.setdefault(line, set())
                    group_set.add(entry)
        except:
            pass
    for key, val in cache.items():
        cache[key] = (",".join(val), val)

    g_cache = cache


def cache_sites():
    global g_site_cache

    base_dir = '/cvmfs/cms.cern.ch/SITECONF'
    cache = {}
    user_re = re.compile(r'[-_A-Za-z0-9.]+')
    sites = None
    try:
        if os.path.isdir(base_dir):
            sites = os.listdir(base_dir)
    except:
        pass
    if not sites:
        g_expire_time = time.time() + 60
        return
    for entry in sites:
        full_path = os.path.join(base_dir, entry, 'GlideinConfig', 'local-users.txt')
        if g_ignore_local and (entry == 'local'):
            continue
        if not os.path.isfile(full_path):
            continue
        groups = cache.setdefault(entry, set())
        groups.add(entry)
        try:
            valid_group_re = re.compile(r"[-_A-Za-z0-9]+")
            if os.path.exists(local_gconf):
                for line in open(local_gconf).xreadlines():
                    line = line.strip()
                    if valid_group_re.match(line):
                        groups.add(line)
        except:
            pass
    for key, val in cache.items():
        cache[key] = (",".join(val), val)

    g_site_cache = cache


def check_caches():
    global g_expire_time
    if time.time() > g_expire_time:
        cache_users()
        cache_sites()
        g_expire_time = time.time() + 15*3600


def map_user_to_groups(user):
    check_caches()
    return g_cache.setdefault(user, ("", set()))[0]


def is_local_user(user, site):
    check_caches()
    user_groups = g_cache.setdefault(user, ("", set()))[1]
    site_groups = g_site_cache.setdefault(site, ("", set()))[1]
    return bool(user_groups.intersection(site_groups))
     

if __name__ == '__main__':
    print map_user_to_groups("bbockelm")
    print is_local_user("bbockelm", "local")

    #import classad
    #classad.register(map_user_to_groups)
    #print classad.ExprTree('map_user_to_groups("bbockelm")').eval()

