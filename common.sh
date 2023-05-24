#!/bin/bash

DIRNAME=$( dirname -- "${BASH_SOURCE[0]}" )

request_epel9_branch() {
    # From https://docs.fedoraproject.org/en-US/epel/epel-package-request/
    local project=$1
    if [ ! -n "$project" ]; then
        echo "Provide a project"
        return 2
    fi
    if grep -q -e $project $DIRNAME/fedora_epel9_active_components; then
        bz_id=$(bugzilla new -i -p "Fedora EPEL" -v epel9 -c $project --summary "Please branch and build $project in epel9" --comment "Please branch and build $project in epel9.")
    else
        bz_id=$(bugzilla new -i -p Fedora -v rawhide -c $project --summary "Please branch and build $project in epel9" --comment "Please branch and build $project in epel9.")
    fi
    if [ $? -eq 0 ]; then
        echo "$bz_id"
        return 0
    else
        echo "$bz_id"
        return 1
    fi
}
