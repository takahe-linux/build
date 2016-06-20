#!/usr/bin/bash
#
# Rebuild all outdated packages.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.2"
USAGE="<config dir> [<target>]..."
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

rebuild_target() {
    # Print the state and rebuild the target.
    print_state "$@"
    rebuild "$@"
}

summary() {
    # Print a summary.

    local rebuilt=0
    local failed=0
    local skipped=0

    for target in ${!targets[@]}; do
        case "${targets["${target}"]}" in
            rebuilt) rebuilt="$(expr "${rebuilt}" + 1)";;
            fail) failed="$(expr "${failed}" + 1)";;
            skip) skipped="$(expr "${skipped}" + 1)";;
        esac
    done

    message info "$(printf "Rebuilt: %s, failed: %s, skipped: %s\n" \
        "${rebuilt}" "${failed}" "${skipped}")"
}

main() {
    # Print the current status.
    local configdir="$1"
    shift
    local target_list="$(get_target_list "${configdir}" "$@")"

    # Start by cleaning the cache - otherwise we cannot check that it is not
    # stale.
    rm -rf "${config[builddir]}/cache"

    # Walk the graph, print the summary.
    walk "${configdir}" "rebuild_target" ${target_list}
    summary
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

