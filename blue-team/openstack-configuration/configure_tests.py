#!/usr/bin/python

import optparse
import logging
import os
import sys
import string
import subprocess
import re


def list_configs(conf_dir):
    confs = []
    for f in os.listdir(conf_dir):
        if os.path.isdir(os.path.join(conf_dir, f)):
            confs += list_configs(os.path.join(conf_dir, f))
        if f.endswith('.conf'):
            confs.append(os.path.join(conf_dir, f))
    return confs

def update_test_configs(conf_dir):
    if not os.path.exists(conf_dir):
        die('Config directory does not exist at %s' % conf_dir)
    vars_file = os.path.join(conf_dir, 'all_variables')
    if not os.path.isfile(vars_file):
        die('Could not load all_variables from %s' % vars_file)

    env_vars = []
    for l in open(vars_file, 'r').readlines():
        if not l.startswith('#') and l.strip() != '':
            env_vars.append(l.strip())

    config_files = list_configs(conf_dir)

    for var in env_vars:
        if var in os.environ:
            val = os.environ[var]
            for f in config_files:
                sep = ","
                if re.search(",", val):
                    sep = "/"
                cmd = 'sed -i s%(sep)s%%%(var)s%%%(sep)s%(val)s%(sep)sg %(f)s' % locals()
                subprocess.check_output(cmd.split(' '))
        else:
            print "[WARN] Not setting %s in config, could not find in environment."\
                % var
    print "Configured tests in %s" % conf_dir

parser = optparse.OptionParser()
parser.add_option('-C', '--configure', dest='configure', action='store_true',
                  default=False,
                  help='Configure all test configs based on enviornment.')
(options, args) = parser.parse_args()

if options.configure:
    if len(args) == 0:
        die('Must pass a directory as argument to --configure')

    conf_dir=args.pop()
    update_test_configs(conf_dir)
