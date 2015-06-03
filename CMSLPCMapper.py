
import os
import time
import tempfile

import classad
import htcondor

g_expire_time = 0
g_cache = set()


def write_cache_file():
    final_fname = get_cache_filename()
    dirname, prefix = os.path.split(final_fname)
    fd, name = tempfile.mkstemp(dirname, prefix)
    try:
        for dn in g_cache:
            fd.write(dn + "\n")
        fd.close()
        fd.rename(name, final_fname)
    except Exception, e:
        htcondor.log(htcondor.LogLevel.Always, "Failed to write out cache file: %s" % str(e))
        try:
            os.unlink(name)
        except:
            pass


def cache_users_from_fd(fd):
    global g_cache
    new_cache = set()
    for line in fd.readlines():
        dn = line.strip()
        if not dn or dn.startswith("#"):
            continue
        new_cache.add(dn)
    g_cache = new_cache


def get_cache_filename():
    return htcondor.param.get('CMSLPC_USER_CACHE', os.path.join(htcondor.param['SPOOL'], 'cmslpc_cache.txt'))


def cache_users_from_file():
    cache_file = get_cache_filename()
    try:
        cache_users_from_fd(open(cache_file, "r"))
    except Exception, e:
        htcondor.log(htcondor.LogLevel.Always, "Failed to cache users from file %s: %s" % (cache_file, str(e)))


def cache_users():
    url = htcondor.param.get("CMSLPC_USER_URL")
    if not url:
        cache_users_from_file()
        return
    try:
        urlfd = urllib.urlopen(url)
        cache_users_from_fd(urlfd)
    except Exception, e:
        htcondor.log(htcondor.LogLevel.Always, "Failed to cache users from URL %s: %s" % (url, str(e)))
        cache_users_from_file()
        return
    write_cache_file()


def check_caches():
    global g_expire_time
    if time.time() > g_expire_time:
        cache_users()
        g_expire_time = time.time() + 15*3600

def lpcUserDN(user):
    check_caches()
    return user in g_cache


classad.register(lpcUserDN)


if __name__ == '__main__':
    htcondor.param['CMSLPC_USER_CACHE'] = 'test_lpccache.txt'
    htcondor.enable_debug()
    print lpcUserDN("/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=bbockelm/CN=659869/CN=Brian Paul Bockelman")
    print classad.ExprTree('lpcUserDN("/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=bbockelm/CN=659869/CN=Brian Paul Bockelman")').eval()
    print lpcUserDN("/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=bbockelm/CN=659869/CN=Brian Paul Bockelman/false")
    print classad.ExprTree('lpcUserDN("/DC=ch/DC=cern/OU=Organic Units/OU=Users/CN=bbockelm/CN=659869/CN=Brian Paul Bockelman/false")').eval()

