# Shared code for the target modules.
# Import this at the start of the target code.

configdir="$(realpath "$1")"
# Load the config; we assume that it has been loaded.
load_config "${configdir}/config"
target="$2"
shift 2

prefix="${target%%/*}"
name="${target#*/}"

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

