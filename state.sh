#!/usr/bin/bash
#
# Print a current state?
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/libmain.sh"
source "$(dirname "$(realpath "$0")")/libbuild.sh"

# Create a new dict of targets.
# This is populated as we go along to avoid repeats, and to save the
# good/bad values. Not that we use those, but...
declare -A old

walk_func() {
    # Walk function passed in...

    configdir="$1"
    shift

    local current_old=false

    # First, check whether any of the dependencies are marked as old.
    for dep in ${graph["$1"]}; do
        if [ -z "${old["${dep}"]}" ]; then
            error 1 "Encountered '$1' before it's dependency '${dep}'!"
        elif "${old["${dep}"]}"; then
            current_old=true
        fi
    done

    # Then check wether this is old.
    if old "${configdir}" "$1"; then
        current_old=true
    fi

    # Finally, print and save the result.
    old["$1"]="${current_old}"
    if "${current_old}"; then
        message warn "$1 is out of date"
    else
        message info "$1 is up to date"
    fi
}

main() {
    # Print the current status.

    # We are interested in the possible targets...
    local target_list=()
    for targ in "${CONFIGDIR}"/src/targets/*; do
        target_list+=("$(echo "${targ}" | grep -o -e '[^/]*/[^/]*$')")
    done
    generate_graph "${CONFIGDIR}" ${target_list[@]}
    walk "walk_func" ${target_list[@]}
}

# Parse the arguments.
parseargs $@ # Initial argument parse.

CONFIGDIR=""
for arg in $@; do
    case "${arg}" in
        --);; # Ignore...
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown argument '${arg}'"
        fi;;
    esac
done
check_configdir "${CONFIGDIR}"

main "${CONFIGDIR}"
