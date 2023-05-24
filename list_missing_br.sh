#!/bin/bash

STATUS_FILE="$HOME/workspace/openstackclient-epel9/status"

missing_brs=$(grep -r -e "No matching package to install:" local_build/current | sed "s/.*No matching package to install: '\(.*\)'/\1/" | awk '{print $1}' | sort | uniq | tr '\n' ' ')
project=$(basename $PWD)

if grep -q -e "$project" $STATUS_FILE; then
    sed -i "s/^$project.*/$project $missing_brs/" $STATUS_FILE
else
    echo -e "$project $missing_brs" >> $STATUS_FILE
fi
sort -o $STATUS_FILE{,}
