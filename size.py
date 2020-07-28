#!/usr/bin/env python
import argparse
import os
import os.path
import time


def sizeof_fmt(num, suffix=''):
    for unit in ['','K','M','G','T','P','E','Z']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


def main(directory=None):
    """
    :param directory: string, a folder on the system
    :return: Tuple with (<total size of folder>, <the number of file in the folder>, <the modification time of the most
    recent file>)
    """

    tot = 0
    nb = [0]
    mod_time = []
    def count(path):
        nb[0] += 1
        mod_time.append(os.path.getmtime(path))
        return os.path.getsize(path)
    for root, dirs, files in os.walk(directory):
        paths = (os.path.join(root, f) for f in files)
        tot += sum(count(path) for path in paths if os.path.isfile(path))
    most_recent = time.ctime(max(mod_time))

    return (tot, nb[0], most_recent)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=str)
    parsed = parser.parse_args()

    directory = parsed.directory
    size_of_directory, nb_file, most_recent_file = main(directory=directory)

    print('{0:>15}, last modif {3:>10}, {2:>12} files for {1:70}'.format(sizeof_fmt(size_of_directory),
                                                                         os.path.abspath(directory),
                                                                         nb_file,
                                                                         most_recent_file))

