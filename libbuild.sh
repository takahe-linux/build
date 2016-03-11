# Build functions.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

declare -A graph    # Visited nodes and dependencies

run_action() {
    # Run the given action for the given target.
    local action="$1"
    local configdir="$2"
    local target="$3"
    shift 3

    path="$(dirname "$(realpath "$0")")/targets/${target%/*}"

    if [ -d "${path}" ]; then
        if [ -e "${path}/${action}" ]; then
            # Run the script to find the current state.
            "${path}/${action}" "${configdir}" "${target}" || exit $?
        else
            error 1 "Target '${target}' does not support action ${action}!"
        fi
    else
        error 1 "Unknown target type '${target%/*}'!"
    fi
}

mark() {
    # Mark the given target as up-to-date.
    configdir="$1"
    target="$2"

    # Create a dir if needed.
    dir="${configdir}/build/$(dirname "${target}")"
    if [ ! -e "${dir}" ]; then
        mkdir -p "${dir}"
    fi

    printf '' > "${configdir}/build/${target}"

    # Save the state for the target and all of the dependencies.
    for dep in "${target}" ${graph["${target}"]}; do

        # Find the current state.
        state="$(run_action state "${configdir}" "${dep}")"
        if [ -z "${state}" ]; then
            exit 2
        elif [ "${state}" == "na" ]; then
            # Ignore 'na'.
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
    for dep in "${target}" ${graph["${target}"]}; do
        # Find the current state.
        state="$(run_action state "${configdir}" "${dep}")"
        if [ -z "${state}" ]; then
            exit 2
        elif [ "${state}" == "na" ]; then
            continue
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

generate_graph() {
    # Generate the graph for the given configuration dir.
    # Note that this is saved to the global variable graph, due to the limits
    # of my bash knowledge. graph is a map from targets to dependencies.
    configdir="$1"
    shift

    local to_visit=($@)     # Nodes to visit

    while [ "${#to_visit[@]}" -gt 0 ]; do
        # Visit a target.
        target="${to_visit[0]}"
        to_visit=(${to_visit[@]:1})

        # Process the dependencies.
        local deps="$(run_action deps "${configdir}" "${target}")"
        # TODO: Figure out how to find out whether the call to get deps succeded
        # Add the item to the graph.
        graph["${target}"]="${deps}"
        # Add it to the to_visit list if it is not in the to_visit list or in
        # the graph.
        for dep in ${deps}; do
            if ! (in_array "${dep}" ${to_visit[@]} || \
                [ -n "${graph["${dep}"]}" ]); then
                to_visit+=("${dep}")
            fi
        done
    done
}

walk() {
    # Walk each target in order, using the prebuilt graph.
    # The traversal is depth first, post order.
    configdir="$1"
    func="$2"
    shift 2

    # We maintain a stack.
    declare -a stack
    # We also note visited nodes.
    declare -A visited

    # For each target, walk the graph.
    for target in $@; do
        # We first check that we have not already visited the given target.
        if [ -n "${visited["${target}"]}" ]; then
            continue
        fi
        stack=("${target}") # Initialise the stack.
        # Walk the graph.
        while [ "${#stack}" -gt 0 ]; do
            local current="${stack[-1]}"

            # Find a unvisited dependencies.
            local unvisited=""
            for dep in ${graph["${current}"]}; do
                if [ -z "${visited["${dep}"]}" ]; then
                    unvisited="${dep}"
                    break
                fi
            done

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
                # Pop it off the stack, mark it as visited, and run the
                # function on it.
                stack=(${stack[@]:0:$(expr ${#stack[@]} - 1)})
                "${func}" "${configdir}" "${current}" "${stack[@]}"
                visited["${current}"]=true
            fi
        done
    done
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
