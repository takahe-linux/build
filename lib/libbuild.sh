# Build functions.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

declare -A graph    # Targets and their dependencies
declare -A requires # Targets and their requires
declare -A states   # Targets and their current state
declare -A targets  # Targets and current build state

run_action() {
    # Run the given action for the given target.
    local action="$1"
    local configdir="$2"
    local target="$3"
    shift 3

    path="$(dirname "$(realpath "$0")")/targets/${target%%/*}"

    message debug "Running '${path}/${action}' for '${target}'..."

    if [ -d "${path}" ]; then
        if [ -e "${path}/${action}" ]; then
            # Run the script to find the current state.
            # If the file doesn't exist, ignore.
            "${path}/${action}" "${configdir}" "${target}" || return $?
        fi
    else
        error 1 "Unknown target type '${target%%/*}'!"
    fi
}

update_state() {
    # Update the state for the given target.
    local configdir target state
    configdir="$1"
    target="$2"

    state="$(run_action state "${configdir}" "${target}" || exit "$?" \
        | tr '\n' ' ')" || exit "$?"
    if [ -z "${state}" ]; then
        error 2 "Invalid state returned for '${target}'!"
    fi
    states["${target}"]="${state}"
}

mark() {
    # Mark the given target as up-to-date.
    local configdir target dir state
    configdir="$1"
    target="$2"

    # Create a dir if needed.
    dir="${configdir}/build/$(dirname "${target}")"
    if [ ! -e "${dir}" ]; then
        mkdir -p "${dir}"
    fi

    printf '' > "${configdir}/build/${target}"

    # Generate and cache the dependency list, if required.
    if [ -z "${graph["${target}"]+is_set}" ]; then
        graph["${target}"]="$(run_action deps "${configdir}" "${target}")" || \
            exit "$?"
    fi

    # Save the state for the target and all of the dependencies.
    for dep in "${target}" ${graph["${target}"]}; do

        # Find the current state.
        state="${states["${dep}"]}"
        if [ -z "${state}" ]; then
            # Generate it if required.
            update_state "${configdir}" "${dep}"
            state="${states["${dep}"]}"
        fi
        if [ "${state}" == "na" ] || [ "${state}" == "old" ]; then
            # Ignore 'na' and 'old'.
            continue
        fi

        # Save the dep and state.
        printf "%s %s\n" "${dep}" "${state}" >> "${configdir}/build/${target}"
    done
}

old() {
    # Return true if the given target is out of date.
    # We consider a target to be out of date if it has changed relative to it's
    # old state (for instance, a file had been modified), or if one of it's
    # dependencies has changed since the target was last updated.
    # We do _not_ traverse down the dependency list.
    # If there is no recorded state, assume that the target is 'old'.
    local configdir="$1"
    local target="$2"
    shift 2

    # Check that the path exists.
    local path="${configdir}/build/${target}"
    if [ ! -f "${path}" ]; then
        # No file; default to old.
        message debug "${target} considered old; no file"
        return 0
    fi

    # Check that the target and all deps are up to date.
    local state
    for dep in "${target}" ${graph["${target}"]}; do
        # Find the current state.
        state="${states["${dep}"]}"
        if [ -z "${state}" ]; then
            # Generate it if required.
            update_state "${configdir}" "${target}"
            state="${states["${dep}"]}"
        fi
        if [ "${state}" == "na" ]; then
            # Ignore 'na'.
            continue
        elif [ "${state}" == "old" ]; then
            # Arbitary 'old'
            message debug "${target} is out of date; ${dep} is old"
            return 0
        fi
        
        # Compare the current to the saved state.
        grep "^${dep} ${state}\$" "${path}" > /dev/null
        if [ "$?" -ne 0 ]; then
            message debug "${target} is out of date; ${dep} old (${state})"
            return 0
        fi
    done
    return 1
}

in_array() {
    # Check if the given argument is in the given bash array.
    # Because bash is... awkward.
    arg="$1"
    shift

    for item in $@; do
        if [ "${arg}" == "${item}" ]; then
            return 0
        fi
    done
    return 1
}

walk() {
    # Walk each target in order, using the prebuilt graph.
    # The traversal is depth first, post order.
    local configdir="$1"
    local func="$2"
    shift 2

    # We maintain a stack.
    declare -a stack
    # We also note visited nodes.
    declare -A visited
    # We also keep track of "required" deps; they need to be built before
    # any of the dep scripts are run which require them.
    declare -A required

    # For each target, walk the graph.
    for target in "$@"; do
        # We first check that we have not already visited the given target.
        if [ -n "${visited["${target}"]}" ]; then
            continue
        fi
        local stack=("${target}") # Initialise the stack.
        # Walk the graph.
        while [ "${#stack}" -gt 0 ]; do
            local current="${stack[-1]}"
            local unvisited=""

            # Generate and cache the requires.
            if [ -z "${requires["${current}"]+is_set}" ]; then
                deps="$(run_action require "${configdir}" "${current}")" || \
                    exit "$?"
                requires["${current}"]="${deps}"
            fi

            # Find an unvisited require.
            local failed=""
            for dep in ${requires["${current}"]}; do
                # Mark the dep as a "required" dep.
                required["${dep}"]="true"
                # Check if the dep is visited.
                if [ -z "${visited["${dep}"]}" ]; then
                    unvisited="${dep}"
                    break
                else
                    # Check that the dependencies all rebuilt properly.
                    if [ "${targets["${dep}"]}" != "rebuilt" ] && \
                        [ "${targets["${dep}"]}" != "good" ]; then
                        failed="${dep} ${failed}"
                    fi
                fi
            done

            # If there are no unvisited (and unbuilt!) requires, then find
            # "normal" dependencies.
            if [ -z "${failed}" ]; then
                if [ -z "${unvisited}" ]; then
                    # Generate and cache the dependency list, if required.
                    if [ -z "${graph["${current}"]+is_set}" ]; then
                        deps="$(run_action deps "${configdir}" "${current}")" \
                            || exit "$?"
                        graph["${current}"]="${deps}"
                    fi

                    # Find an unvisited dependency.
                    for dep in ${graph["${current}"]}; do
                        # If this is marked as required, then mark the deps as
                        # required.
                        if [ "${required["${current}"]}" == "true" ]; then
                            required["${dep}"]="true"
                        fi
                        # Check if the dep is visited.
                        if [ -z "${visited["${dep}"]}" ]; then
                            unvisited="${dep}"
                            break
                        fi
                    done
                fi
            else
                # We have a failure; print a warning and ignore.
                message warn \
                    "Failed to generate the dependencies for ${current} ([${failed:0:-1}] failed)!"
            fi

            if [ -n "${unvisited}" ]; then
                # The current node has an unvisited dependency - add it to
                # the stack.
                # We also check that it is not already in the stack, that is,
                # that the graph is non-cyclic.
                if in_array "${unvisited}" ${stack[@]}; then
                    message error "${current} -> ${unvisited}"
                    while [ "${current}" != "${unvisited}" ]; do
                        # Pop the thing of the top of the stack...
                        stack=(${stack[@]:0:$(expr ${#stack[@]} - 1)})
                        message error "${stack[-1]} -> ${current}"
                        current="${stack[-1]}"
                    done
                    error 2 "Circular dependency detected!"
                fi
                stack+=("${unvisited}")
            else
                # The current node does not have an unvisited dependency.
                # Pop it off the stack.
                stack=(${stack[@]:0:$(expr ${#stack[@]} - 1)})

                # Update the state of the target.
                update_target "${configdir}" "${current}"

                # Call the function.
                "${func}" "${configdir}" "${current}" "${stack[@]}"

                # If it is "required", rebuild it.
                if [ -n "${required["${current}"]}" ]; then
                    rebuild "${configdir}" "${current}"
                fi
                
                # Mark it as visited.
                visited["${current}"]=true
            fi
        done
    done
}

update_target() {
    # Get the state of the given target, as needed.
    # We consider 5 states: rebuilt, old, fail, skip, and good.
    local configdir="$1"
    shift
    local current_state="good"

    # Check that all of the requires built.
    for dep in ${requires["$1"]}; do
        if [ -z "${targets["${dep}"]}" ]; then
            error 1 "Encountered '$1' before it's require '${dep}'!"
        fi
        case "${targets["${dep}"]}" in
            # We need all the dependencies to be good or rebuilt.
            old|fail|skip) current_state="skip"; break;;
        esac
    done

    # Check the state of the dependencies, if all the requires built.
    if [ "${current_state}" == "good" ]; then
        for dep in ${graph["$1"]}; do
            if [ -z "${targets["${dep}"]}" ]; then
                error 1 "Encountered '$1' before it's dependency '${dep}'!"
            fi
            case "${targets["${dep}"]}" in
                old|rebuilt) current_state="old";;
                fail|skip) current_state="skip"; break;;
            esac
        done
    fi

    # If this is still marked as good check wether this is old.
    if [ "${current_state}" == "good" ] && old "${configdir}" "$1"; then
        current_state="old"
    fi

    # Save the state.
    message debug "State of '$1' is '${current_state}'"
    targets["$1"]="${current_state}"
}

print_state() {
    # Print the current state of the given target.
    local configdir="$1"
    shift
    case "${targets["$1"]}" in
        old) message warn "$1 is out of date";;
        skip) message warn "Skipping $1";;
        good) message info "$1 is up to date";;
        *) message error "Unknown state for $1 '${targets["$1"]}'";;
    esac
}

rebuild() {
    # Rebuild the given target, if needed.
    local configdir="$1"
    shift

    current_state="${targets["$1"]}"
    if [ -z "${current_state}" ]; then
        # We have not found the state of the target.
        error 1 "Cannot rebuild '${1}' before it's state is found!"
    fi
    if [ "${current_state}" != "old" ]; then
        # Abort; this does not need rebuilding.
        return
    fi

    # Rebuild; this is old.
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
    fi
}

get_target_list() {
    # Print a list of targets. Default is all of the targets found in the
    # source directory.
    local configdir="$1"
    shift

    if [ "$#" -eq 0 ]; then
        local target_list=()
        for targ in "${CONFIGDIR}"/src/targets/*; do
            target_list+=("$(echo "${targ}" | grep -o -e '[^/]*/[^/]*$')")
        done
    else
        local target_list=$@
    fi
    printf "${target_list}"
}
