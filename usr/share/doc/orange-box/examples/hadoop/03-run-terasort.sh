#!/bin/bash
juju ssh hadoop-namenode/0 "sudo -u hdfs /usr/lib/hadoop/terasort.sh"
