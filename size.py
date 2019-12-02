#!/usr/bin/env python
import os
import os.path
import sys

def sizeof_fmt(num, suffix=''):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


tot = 0 
for root, dirs, files in os.walk(sys.argv[1]):
    paths = (os.path.join(root, f) for f in files)
    tot += sum(os.path.getsize(path) for path in paths if  os.path.isfile(path))
    #for p in paths:
    #    print(p)
    #    print(os.path.getsize(p))
print('{:15} for {:70}'.format(sizeof_fmt(tot),os.path.abspath(sys.argv[1])))             

