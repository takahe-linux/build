# Shared code for the target modules.
# Import this at the start of the target code.

configdir="$1"
target="$2"
shift 2

exists() {
    # Check that the given file exists.
    if [ ! -f "$1" ]; then
        error 1 "No such target '${target}'!"
    fi
}

sum_file() {
    # Print a hash for the given file.
    exists "$1"
    md5sum "$1" | cut -d' ' -f1
}

randomise() {
    # Randomise the given inputs.

    # TODO: Nondeterminism is useful for testing, but having a flag to turn
    #       it off would be good.
    shuf < /dev/stdin
}
