#!/bin/bash

project=$(basename $PWD)
fedpkg pull
if ! git branch --all | grep -q -e "epel9"; then
    bzs=$(bugzilla query -p Fedora -c $project)
    if ! echo -e "$bzs" | grep -q -i -e "epel9"; then
    else
        echo "Needs to check"
        echo -e "$bzs" | grep -i -e "epel9"
    fi
fi
