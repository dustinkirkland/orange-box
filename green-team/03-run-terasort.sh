#!/bin/bash
juju ssh hadoop-master/0 "sudo -u hdfs /usr/lib/hadoop/terasort.sh"
