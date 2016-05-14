#!/usr/bin/bash
#
# Rebuild all outdated packages.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir> [<target>]..."
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

# Create a new dict of targets, marking their current states.
declare -A targets

rebuild() {
    # Rebuild the given target, as needed.
    # We consider 5 states: rebuilt, old, fail, skip, and good.
    configdir="$1"
    shift
    local current_state="good"

    # Check wether this is old.
    if old "${configdir}" "$1"; then
        current_state="old"
    fi

    # Check the state of the dependencies.
    for dep in ${graph["$1"]}; do
        if [ -z "${targets["${dep}"]}" ]; then
            error 1 "Encountered '$1' before it's dependency '${dep}'!"
        fi
        case "${targets["${dep}"]}" in
            old|rebuilt) current_state="old";;
            fail|skip) current_state="skip"; break;;
        esac
    done

    # Figure out the appropriate action.
    targets["$1"]="${current_state}"
    case "${current_state}" in
        old) message warn "$1 is out of date"
            # Create a temporary document for the build log.
            local buildlog="$(mktemp "${TMPDIR:-/tmp}/build-$(echo "$1" \
                | tr '/' '_')".XXXXXXXX)"
            run_action build "${configdir}" "$1" > "${buildlog}" 2>&1
            if [ "$?" -ne 0 ]; then
                message error "Last 10 lines of the build log (${buildlog}):"
                tail -n 10 "${buildlog}" | sed 's:^:    :' > /dev/stderr
                message error "Failed to build '$1'!"
                targets["$1"]="fail"
            else
                update_state "${configdir}" "$1"
                if [ "${states["$1"]}" == "old" ]; then
                    message error "Built target '$1' is still 'old'!"
                    targets["$1"]="fail"
                else
                    rm -f "${buildlog}"
                    mark "${configdir}" "$1" || \
                        error "$?" "Invalid target '$1'!"
                    targets["$1"]="rebuilt"
                fi
            fi;;
        skip) message warn "Skipping $1";;
        *) message info "$1 is up to date";;
    esac
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
    local target_list="$(get_target_list "${configdir}" $@)"
    generate_graph "${configdir}" ${target_list}
    walk "${configdir}" "rebuild" ${target_list}
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
check_configdir "${CONFIGDIR}"

main "${CONFIGDIR}" ${TARGETS}

