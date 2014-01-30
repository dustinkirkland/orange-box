#!/usr/bin/python

import sys
import subprocess

import simplejson as json


def set_fast_path(nodes=None):
    if not nodes:
        raise ValueError('Need an array of nodes')

    if not isinstance(nodes, list):
        nodes = [nodes]

    if len(nodes) < 1:
        return

    try:
        cmd = ['maas-cli', 'admin', 'tag', 'update-nodes',
               'use-fastpath-installer']
        for node in nodes:
            cmd.append('add=%s' % node)
        subprocess.check_call(cmd)
    except Exception:
        raise


def get_nodes_from_json(nodes_json):
    nodes_obj = json.loads(nodes_json)
    nodes = []
    for node_detail in nodes_obj:
        nodes.append(node_detail['system_id'])

    return nodes


def main():
    raw_json = sys.argv[1]
    nodes = get_nodes_from_json(raw_json)
    set_fast_path(nodes)

if __name__ == '__main__':
    main()
