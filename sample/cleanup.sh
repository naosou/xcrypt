#!/bin/bash

find . -name "*.xcr.pl"| xargs rm -f
find . -name "bulk[0-9]*"| xargs rm -rf
find . -name "job[0-9]*"| xargs rm -rf
find . -name ".tmp"| xargs rm -rf
find . -name "inv_watch"| xargs rm -rf
find . -name "invwrite-sock.log"| xargs rm -f
find . -name "invwrite-file.log"| xargs rm -f
