# Build functions.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

declare -A graph    # Visited nodes and dependencies

current_state() {
    # Print the current state for the given target, determined as appropriate.
    configdir="$1"
    target="$2"

    # TODO: This should be more flexible...
    case "${target%/*}" in
        targets) md5sum "${configdir}/src/${target}" | cut -d' ' -f1;;
        packages|toolchain) md5sum "${configdir}/src/${target}/PKGBUILD" \
            | cut -d' ' -f1;;
        actions) echo "na" ;; # Actions do not have a state, yet.
        *) error 2 "Unknown target '${target}'!";;
    esac
}

mark() {
    # Mark the given target as up-to-date.
    configdir="$1"
    target="$2"

    state="$(current_state "${configdir}" "${target}")"
    if [ -z "${state}" ]; then
        exit 2
    fi
    dir="${configdir}/build/$(dirname "${target}")"
    if [ ! -e "${dir}" ]; then
        mkdir -p "${dir}"
    fi
    echo "${state}" > "${configdir}/build/${target}"
}

old() {
    # Return true if the given target is out of date.
    # We consider a target to be out of date if it has changed (we ignore
    # dependencies), so we compare the current state with the old state.
    # If there is no recorded state, assume that the target is 'old'.
    configdir="$1"
    target="$2"
    shift 2

    state="$(current_state "${configdir}" "${target}")"
    if [ -z "${state}" ]; then
        exit 2
    elif [ "${state}" == "na" ]; then
        return 1
    fi
    if [ -f "${configdir}/build/${target}" ] && \
        [ "${state}" == "$(cat "${configdir}/build/${target}")" ]; then
        return 1
    fi
}

depends() {
    # Print the dependencies of the given target.
    configdir="$1"
    target="$2"

    case "${target%/*}" in
        targets) cat "${configdir}/src/${target}" || \
            error 1 "Target ${target} does not exist!";;
        packages|toolchain) # Extract the depends from the PKGBUILD
            echo "actions/setup.sh"; \
            sed -n -e 's:  *: :g' -e '/# Depends:/p' \
            < "${configdir}/src/${target}/PKGBUILD" | \
            sed -e 's:# Depends\:::' | \
            tr ' ' '\n' | \
            shuf;;
            # TODO: Nondeterminism is useful for testing, but having a flag to
            #       turn it off would be good.
        actions) : # Actions do not have deps.
            ;;
        *) error 2 "Unknown target '${target}'!"
    esac
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
        local deps="$(depends "${configdir}" "${target}")"
        # Add the item to the graph.
        graph["${target}"]="${deps}"
        # Add it to the to_visit list if it is not in the to_visit list or in
        # the graph.
        for dep in ${deps}; do
            if ! (in_array "${dep}" ${to_visit[@]} || [ -n "${graph["${dep}"]}" ]); then
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
                "${func}" "${configdir}" "${current}"
                visited["${current}"]=true
            fi
        done
    done
}

