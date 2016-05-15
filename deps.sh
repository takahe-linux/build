#!/usr/bin/bash
#
# List the dependencies of the given targets.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir> [<target>]..."
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

print_target() {
    # Print the given target.
    local configdir="$1"
    local target="$2"
    shift 2

    for d in $(seq "$#"); do
        printf "  "
    done
    printf "%s\n" "${target}"
}

main() {
    # List the dependencies of the given targets.
    local configdir="$1"
    shift
    local target_list="$(get_target_list "${configdir}" $@)"
    # TODO: Use my own tree traversal code to fix it being up the wrong way,
    #       not repeating targets, and without much in the way of visual cues
    #       for how things join up.
    walk "${CONFIGDIR}" "print_target" ${target_list} | tac
}

# Parse the arguments.
CONFIGDIR="" # Set the initial config dir.
TARGETS="" # The set of targets to investigate.
parseargs "$@" # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            TARGETS+=" ${arg}"
        fi;;
    esac
done
check_configdir "${CONFIGDIR}"

main "${CONFIGDIR}" ${TARGETS}
