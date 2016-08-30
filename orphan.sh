#!/usr/bin/bash
#
# List orphaned packages.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

main() {
    local configdir="$1"
    shift

    # Walk the graph; we then check that everything is covered.
    walk "${configdir}" "true" $(get_target_list "${configdir}")

    # Check that everything was covered.
    local pkg
    find "${configdir}" -name .SRCINFO | rev | cut -d'/' -f2-3 | rev | \
    while IFS= read pkg; do
        if [ -z "${graph[${pkg}]+is_set}" ]; then
            printf "%s\n" "${pkg}"
        fi
    done
}

# Parse the arguments.
CONFIGDIR=""    # Set the initial config dir.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown arg '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}"
