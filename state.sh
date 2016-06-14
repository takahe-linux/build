#!/usr/bin/bash
#
# Print a list of old or outdated packages.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir> [<target>]..."
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

main() {
    # Print the current status.
    local configdir="$1"
    shift
    local target_list="$(get_target_list "${configdir}" $@)"
    walk "${configdir}" "print_state" ${target_list}
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
setup "${CONFIGDIR}"

main "${CONFIGDIR}" ${TARGETS}
