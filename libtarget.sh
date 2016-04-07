# Shared code for the target modules.
# Import this at the start of the target code.

configdir="$1"
target="$2"
shift 2

prefix="${target%%/*}"
name="${target#*/}"

declare -A config   # Config file contents.

exists() {
    # Check that the given file exists.
    if [ ! -e "$1" ]; then
        error 1 "No such target '${target}'!"
    fi
}

sum_file() {
    # Print a hash for the given file.
    if [ ! -f "$1" ]; then
        echo "old"
    else
        md5sum "$1" | cut -d' ' -f1
    fi
}

randomise() {
    # Randomise the given inputs.

    # TODO: Nondeterminism is useful for testing, but having a flag to turn
    #       it off would be good.
    shuf < /dev/stdin
}

read_config() {
    # Read the contents of the config file.
    local contents key

    while IFS= read contents; do
        # Parse the line, ignoring comments.
        if [ "${contents:0:1}" != "#" ] && [ "${#contents}" -gt 0 ]; then
            # We assume that each line is of the form x = y, where x is the
            # variable name and y is the contents.
            # TODO: Add more sanity checking.
            key="$(cut -d= -f1 < <(printf "${contents}") | \
                sed -e 's:[ \t]*$::')" || \
                error 1 "Failed to parse '${contents}' in '${configdir}/config'"
            if printf "${key}" | tr '\t' ' ' | grep -e '\ ' > /dev/null; then
                error 1 "'${key}' in '${contents}' from '${configdir}/config' contains whitespace!"
            fi
            config["${key}"]="$(cut -d'=' -f2 < <(printf "${contents}") | \
                sed -e 's:^[ \t]*::' -e 's:[ \t]*$::')" || \
                error 1 "Failed to parse '${contents}' in '${configdir}/config'"
        fi
    done < <(sed "${configdir}/config" -e 's:^[ \t]*::')

    # Sanitize the result.
    for key in id arch triplet cflags ldflags; do
        if [ -z "${config["${key}"]}" ]; then
            error 2 "'${key}' is not defined in '${configdir}/config'!"
        fi
    done
}

