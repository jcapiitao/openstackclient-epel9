#!/bin/bash

DIRNAME=$(dirname -- "${BASH_SOURCE[0]}")
STATUS_FILE="$HOME/workspace/openstackclient-epel9/status"
DISTGIT_PATH="$HOME/workspace/packages/python-openstackclient-epel9/"
PROJECTS_BZID_PATH="$DISTGIT_PATH/projects_bzid"
BZ_IGNORED_PATH="$DISTGIT_PATH/bz_ignored"

file_bz_branch_and_build_on_epel9() {
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
        echo -e "$bz_id" > $PROJECTS_BZID_PATH/$project
        echo "$bz_id"
        return 0
    else
        echo "$bz_id"
        return 1
    fi
}

get_comp() {
    local project=$1
    if [ ! -n "$project" ]; then
        project=$(basename $PWD)
    fi
    if grep -q -e "$project" $DIRNAME/fedora_epel9_active_components; then
        echo "Fedora EPEL"
    else
        echo "Fedora"
    fi
}

get_project() {
    local project=$1
    if [ ! -n "$project" ]; then
        echo $(basename $PWD)
    else
        echo $project
    fi
}

find_epel9_branch_ticket() {
    local project=$(get_project $1)
    local component=$(get_comp $project)
    local bug_id=""
    local bz_ignored=""

    bug_id=$(is_bz_id_stored $project)
    if [ $? -eq 0 ]; then
        echo -e "$bug_id"
        return 0
    fi

    
    sed -i '/^[[:space:]]*$/d' $BZ_IGNORED_PATH
    bz_ignored=$(sed 's/^\(.*\)$/-e\ \1/g' $BZ_IGNORED_PATH | tr '\n' ' ')
    if [ -n "$bz_ignored" ]; then
        bugs=$(bugzilla query -p "$component" -c $project -s CLOSED | grep -i -e "Please .*epel9$" -e "Please.*epel 9$" | grep -v $bz_ignored)
    else
        bugs=$(bugzilla query -p "$component" -c $project -s CLOSED | grep -i -e "Please .*epel9$" -e "Please.*epel 9$")
    fi

    if [ -n "$bugs" ]; then
        echo -e "A EPEL9 ticket was already closed. Needs a manual check. Exiting."
        echo -e "To ignore the ticket, add its ID to the $BZ_IGNORED_PATH file"
        echo -e "e.g: echo 2210073 >> $BZ_IGNORED_PATH\n"
        echo -e "$bugs"
        return 2
    fi

    bugs=""
    if [ -n "$bz_ignored" ]; then
        bugs=$(bugzilla query -p "$component" -c $project -s NEW,OPEN,ASSIGNED,MODIFIED,ON_DEV,ON_QA | grep -i -e "Please .*epel9$" -e "Please.*epel 9$" | grep -v $bz_ignored)
    else
        bugs=$(bugzilla query -p "$component" -c $project -s NEW,OPEN,ASSIGNED,MODIFIED,ON_DEV,ON_QA | grep -i -e "Please .*epel9$" -e "Please.*epel 9$")
    fi

    if [ $(echo -e "$bugs" | wc -l) -gt 1 ]; then
        echo -e "There are more than 1 open ticket. Needs a manual check. Exiting."
        echo -e "To ignore the ticket, add its ID to the $BZ_IGNORED_PATH file"
        echo -e "e.g: echo 2210073 >> $BZ_IGNORED_PATH\n"
        echo -e "$bugs"
        return 3
    fi

    bug_id=$(echo -e "$bugs" | grep -e "OPEN" -e "NEW" -e "ASSIGNED" | sed 's/#\([0-9]*\) .*/\1/')
    if [ -n "$bug_id" ]; then
        echo -e "$bug_id" > $PROJECTS_BZID_PATH/$project
        echo -e "$bug_id"
        return 0
    else
        return 1
    fi
}

is_bz_id_stored() {
    local project=$(get_project $1)
    if [ -f $PROJECTS_BZID_PATH/$project ]; then
        cat $PROJECTS_BZID_PATH/$project
        return 0
    else
        return 1
    fi
}

is_fedora_repo() {
    if git remotes 2>/dev/null | grep -q -e "pkgs.fedoraproject.org"; then
        return 0
    else
        return 1
    fi
}

is_epel9_branch() {
    if git branch --all | grep -q -e "epel9$"; then
        return 0
    else
        return 1
    fi
}

is_local_build() {
    if [ -d local_build/current ]; then
        return 0
    else
        return 1
    fi
}

request_epel9_branch() {
    if ! is_fedora_repo; then
        echo "It's not a Fedora repo"
        return 1
    fi
    git fetch --all
    if is_epel9_branch; then
        echo "The repo has already an epel9 branch"
        return 0
    fi

    local project=$(get_project)
    local bug_id=$1
    if [ ! -n "$bug_id" ]; then
        bug_id=$(find_epel9_branch_ticket $project)
        if [ $? -ne 0 ]; then
            echo -e "$bug_id"
            return 1
        fi
    fi
    if ! git remote | grep -q -e "jcapitao"; then
        pagure_url=$(fedpkg request-branch epel9)
        if [ $? -eq 0 ]; then
            echo -e "The epel9 branch has been requested"
            echo -e "Updating the BZ ticket with the pagure URL"
            bugzilla modify $bug_id -a jcapitao@redhat.com -s ASSIGNED --comment "$pagure_url"   
        else
            echo -e "An error occurred when requesting the epel9 branch to Pagure"
            echo -e "$pagure_url"
            return 1
	fi
    else
        echo -e "You are not owner of this repo, you cannot request epel9 branch"
        return 1
    fi
}

list_missing_brs() {
    if ! is_local_build; then
        echo "There is no local build"
        return 1
    fi
    local missing_brs=$(grep -r -e "No matching package to install:" local_build/current | sed "s/.*No matching package to install: '\(.*\)'/\1/" | awk '{print $1}' | sort | uniq | sed 's/^python3-/python-/;s/python3dist(\(.*\))/python-\1/g' | tr '\n' ' ')
    echo -e "$missing_brs"
}
    
update_status() {
    local project=$(get_project)
    local missing_brs=$(list_missing_brs)
    if grep -q -e "^$project" $STATUS_FILE; then
        sed -i "s/^$project.*/$project $missing_brs/" $STATUS_FILE
    else
        echo -e "$project $missing_brs" >> $STATUS_FILE
    fi
    sort -o $STATUS_FILE{,}
}

list_projects_blocked_by_this_one() {
    local project=$(get_project $1)
    grep -e " $project" $STATUS_FILE | awk '{print $1}'
}

update_bz_ticket_depends_on() {
    local main_project=$(get_project)
    local main_bug_id=$(find_epel9_branch_ticket $main_project)
    local bug_id=""
    local bug_ids=""
    local needs_update=false

    current_depends_on=$(bugzilla query -b $main_bug_id --raw | grep -e "depends_on")
    for project in $(list_missing_brs); do
        bug_id=$(find_epel9_branch_ticket $project)
        if [ $? -eq 0 ]; then
            bug_ids="$bug_ids $bug_id"
            if ! echo -e "$current_depends_on" | grep -q -e "$bug_id"; then
                needs_update=true
            fi
        fi
    done
    if [ -n "$bug_ids" ] && [ "$needs_update" = true ]; then
        bug_ids=$(echo -e "$bug_ids" | sed 's/\ //;s/\ /,/g')
        bugzilla modify $main_bug_id --dependson $bug_ids
        echo -e "https://bugzilla.redhat.com/show_bug.cgi?id=$main_bug_id depends-on updated"
    else
        echo -e "Nothing to update for depends-on"
    fi
}

update_bz_ticket_blocks() {
    local main_project=$(get_project)
    local main_bug_id=$(find_epel9_branch_ticket $main_project)
    local bug_id=""
    local bug_ids=""
    local needs_update=false

    current_blocks=$(bugzilla query -b $main_bug_id --raw | grep -e "blocks")
    for project in $(list_projects_blocked_by_this_one); do
        bug_id=$(find_epel9_branch_ticket $project)
        if [ $? -eq 0 ]; then
            bug_ids="$bug_ids $bug_id"
            if ! echo -e "$current_blocks" | grep -q -e "$bug_id"; then
                needs_update=true
            fi
        fi
    done
    if [ -n "$bug_ids" ] && [ "$needs_update" = true ]; then
        bug_ids=$(echo -e "$bug_ids" | sed 's/\ //;s/\ /,/g')
        bugzilla modify $main_bug_id --blocked $bug_ids
        echo -e "https://bugzilla.redhat.com/show_bug.cgi?id=$main_bug_id blocks updated"
    else
        echo -e "Nothing to update for blocks"
    fi
}

get_latest_koji_build_nvr() {
    local project=$(get_project)
    local build_nvr=""

    build_nvr=$(koji latest-build --quiet epel9-testing-candidate $project | awk '{print $1}')
    if [ -n "$build_nvr" ]; then
        echo -e "$build_nvr"
        return 0
    else
        echo -e "$build_nvr"
        return 1
    fi
}

get_latest_koji_build_task_url() {
    local project=$(get_project)
    local build_nvr=""

    build_nvr=$(get_latest_koji_build_nvr)
    if [ $? -ne 0 ]; then
        echo -e "Could not get the latest koji build NVR"
        echo -e "$build_nvr"
        return 1
    fi

    build_info=$(koji buildinfo $build_nvr)
    if [ $? -ne 0 ]; then
        echo -e "An error occurred when querying the build info"
        echo -e "$build_info"
        return 1
    fi

    build_task=$(echo -e "$build_info" | grep -e "^Task" | awk '{print $2}')
    if [ $? -eq 0 ]; then
        echo -e "https://koji.fedoraproject.org/koji/taskinfo?taskID=$build_task"
        return 0
    fi
}

add_latest_epel9_build_to_bz_ticket() {
    local bug_id=$1
    local build_task_url=''

    if [ ! -n "$bug_id" ]; then
        bug_id=$(find_epel9_branch_ticket $project)
        if [ $? -ne 0 ]; then
            echo -e "$bug_id"
            return 1
        fi
    fi

    build_task_url=$(get_latest_koji_build_task_url)
    if [ $? -eq 0 ]; then
        output=$(bugzilla modify $bug_id --comment "$build_task_url")
        if [ $? -eq 0 ]; then
            echo -e "https://bugzilla.redhat.com/show_bug.cgi?id=$bug_id commented with the latest build task url"
            return 0
        else
            echo -e "An error occurred when commenting the BZ ticket with the latest build task url"
            echo -e "$output"
            return 1
        fi
    fi
}

submit_to_boddhi() {
    local bug_id=$1
    local build_nvr=""

    if [ ! -n "$bug_id" ]; then
        bug_id=$(find_epel9_branch_ticket $project)
        if [ $? -ne 0 ]; then
            echo -e "$bug_id"
            return 1
        fi
    fi

    build_nvr=$(get_latest_koji_build_nvr)
    if [ $? -ne 0 ]; then
        echo -e "Could not get the latest koji build NVR"
        echo -e "$build_nvr"
        return 1
    fi
    bodhi updates new --type newpackage --notes "Latest build for EPEL 9" --autotime --bugs $bug_id --close-bugs $build_nvr
}

print_projects_not_processed() {
    local projects=$(cat $STATUS_FILE | tr ' ' '\n' | grep -e "^python" | sort | uniq | sed '/^$/d' | tr '\n' ' ')
    for p in $projects; do
        if [ "$p" == "python-mock" ]; then
            continue
        fi
        if ! grep -q -e "^$p" $STATUS_FILE; then
            echo -e "$p"
        fi
    done
}

process_epel9() {
    if ! is_fedora_repo; then
        echo "It's not a Fedora repo"
        return 1
    fi
    local project=$(get_project)
    local bug_id=""

    update_status

    # Filing a BZ ticket or fetching the ID
    echo -e "Checking if a BZ ticket already exists"
    bug_id=$(find_epel9_branch_ticket $project)
    if [ $? -ne 0 ]; then
        echo -e "No BZ ticket found"
        echo -e "Filing the BZ ticket"
        bug_id=$(file_bz_branch_and_build_on_epel9 $project)
        if [ $? -ne 0 ]; then
            echo -e "An error occurred during the creation of the BZ ticket"
            echo -e "$bug_id"
            return 1
        else
            echo -e "The BZ ticket is now created $bug_id"
        fi
    else
        echo -e "The BZ ticket ID was already created $bug_id"
    fi

    # Editing the BZ tickets that are blocked by this one
    update_bz_ticket_depends_on
    update_bz_ticket_blocks
    request_epel9_branch $bug_id
    echo -e "https://bugzilla.redhat.com/show_bug.cgi?id=$bug_id"
}
