#!/bin/bash
cat $1 | awk "{print \$2, \$0}" | sort -nr | cut -d ' ' -f 2
