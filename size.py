#!/usr/bin/env python
import os
import os.path
import sys
import time

def sizeof_fmt(num, suffix=''):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


tot = 0 
nb = [0]
mod_time=[]
def count(path):
    nb[0] +=1 
    mod_time.append(os.path.getmtime(path))
    return os.path.getsize(path)
for root, dirs, files in os.walk(sys.argv[1]):
    paths = (os.path.join(root, f) for f in files)
    tot += sum(count(path) for path in paths if  os.path.isfile(path))
    #for p in paths:
    #    print(p)
    #    print(os.path.getsize(p))
most_recent=time.ctime(max(mod_time))
print('{0:>15}, last modif {3:>10}, {2:>12} files for {1:70}'.format(sizeof_fmt(tot), os.path.abspath(sys.argv[1]), nb[0], most_recent))             

