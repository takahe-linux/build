#!/usr/bin/bash
#
# List the dependencies of the given targets.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="1.0"
USAGE="<config dir> [--no-pretty] [--prefix=<prefix> ...] [<target>]..."
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

print_target() {
    # Print the given target.
    local configdir="$1"
    local target="$2"
    shift 2
    for d in "$@"; do
        printf "  "
    done

    printf "%s\n" "${target}"
}

pprint_target() {
    # Print the given target.
    local configdir="$1"
    local target="$2"
    shift 2

    local counter="$#"
    for d in "$@"; do
        # Decrement the counter.
        counter="$(expr "${counter}" - 1)"
        # Print the chars.
        if [ "${counter}" -eq 0 ]; then
            if [ "${d}" -eq 0 ]; then
                # Last item; we print a '\'
                printf "\\_ "
            else
                printf "|- "
            fi
        else
            if [ "${d}" -eq 0 ]; then
                # Blank (column ended earlier)
                printf "   "
            else
                printf "|  "
            fi
        fi
    done

    tput bold
    printf "%s/" "${target%%/*}"
    tput setaf 2
    printf "%s\n" "${target#*/}"
    tput sgr0
}

main() {
    # List the dependencies of the given targets.
    local configdir="$1"
    local no_pretty="$2"
    local prefixes="$3"
    shift 3
    local target_list="$(get_target_list "${configdir}" $@)"

    # Start by doing an initial walk of the graph to ensure that everything is
    # setup properly.
    walk "${CONFIGDIR}" "true" ${target_list}
    # Check that nothing failed; if something did fail, we cannot proceed.
    for state in ${targets}; do
        if [ "${state}" != "rebuilt" ] && [ "${state}" != "good" ]; then
            error 1 "Cannot proceed due to target in state '${state}'!"
        fi
    done

    # We then do a 'dumb' depth first preorder search for each target.
    for target in ${target_list}; do
        # Run the search.
        local stack=("${target}")
        local depcount=() # Remaining dependencies left.
        while [ "${#stack}" -gt 0 ]; do
            # Pop an item off the top of the stack.
            local current="${stack[-1]}"
            stack=(${stack[@]:0:$(expr ${#stack[@]} - 1)})

            # Print the target out.
            if "${no_pretty}"; then
                print_target "${configdir}" "${current}" "${depcount[@]}"
            else
                pprint_target "${configdir}" "${current}" "${depcount[@]}"
            fi

            # Add the dependencies to the stack.
            if [ -z "${graph["${current}"]+is_set}" ]; then
                error 1 "BUG: target '${current}' is not in the graph!"
            fi
            local counter dep
            counter=0
            for dep in ${graph["${current}"]}; do
                # Check if the dep is in prefixes or the list of prefixes
                # is zero length (no restriction).
                local depprefix="${dep%%/*}"
                if [ -z "${prefixes}" ]; then
                    stack+=("${dep}")
                    counter="$(expr "${counter}" + 1)"
                else
                    for prefix in ${prefixes}; do
                        if [ "${prefix}" == "${depprefix}" ]; then
                            stack+=("${dep}")
                            counter="$(expr "${counter}" + 1)"
                            break
                        fi
                    done
                fi
            done
            depcount+=("${counter}")

            while [ "${depcount[-1]}" -lt 1 ] && \
                [ "${#depcount[@]}" -gt 1 ]; do
                # Last of the deps; go up a level.
                depcount=(${depcount[@]:0:$(expr ${#depcount[@]} - 1)})
            done
            depcount[-1]="$(expr "${depcount[-1]}" - 1)"
        done
    done
}

# Parse the arguments.
CONFIGDIR=""        # Set the initial config dir.
TARGETS=""          # The set of targets to investigate.
NO_PRETTY="false"   # Whether or not to use pipe characters.
PREFIXES=""         # Dep types to include.
parseargs "$@" # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        --no-pretty) NO_PRETTY="true";;
        --prefix=*) PREFIXES+=" ${arg:9}";;
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            TARGETS+=" ${arg}"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}" "${NO_PRETTY}" "${PREFIXES}" ${TARGETS}
