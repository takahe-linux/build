#!/usr/bin/bash
#
# Run all of the tests if src/tests/*
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e

# Initial setup.
VERSION="0.1"
USAGE="<config dir> [--timeout=<seconds>]"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"
source "$(dirname "$(realpath "$0")")/lib/libboot.sh"

main() {
    # Generate the fs and boot.
    local configdir="$1"
    local timeout="$2"
    shift 2

    local fs="${config[builddir]}/tests"
    local log="${config[builddir]}/logs/test.log"
    mkdir -p "${fs}/var/lib/pacman"

    # Generate the list of packages and install them.
    message info "Populating test environment..."
    callpacman "${fs}" --needed --arch "${config[arch]}" \
        -U $(printallpkgs "${configdir}" packages native) > "${log}" 2>&1

    # Add the initial scripts.
    gendefhostname "${fs}"
    genfstab "${fs}"
    geninitscript "${fs}" "/tests/run.sh"

    # Generate the test runner.
    rm -rf "${fs}/tests"
    mkdir "${fs}/tests"
    cat > "${fs}/tests/run.sh" << EOF
#!/usr/bin/sh
# Test runner.
for file in /tests/*; do
    if [ "\${file: -5}" == ".test" ]; then
        out="\${file::-5}.out"
        rm -f "\${out}"
        touch "\${out}"
        timeout -t ${timeout} "\${file}" >> "\${out}" || \
            echo "Did not run - error '\$?' (possibly timeout)" >> "\${out}"
    fi
done
EOF
    chmod +x "${fs}/tests/run.sh"
    root_own "${fs}" "tests/run.sh"

    # Install the test scripts.
    for test_script in "${configdir}/src/tests"/*; do
        if [ -x "${test_script}" ]; then
            cp "${test_script}" "${fs}/tests/"
            root_own "${fs}" "tests/${test_script##*/}"
        fi
    done

    # Run qemu and exit.
    message info "Running test scripts..."
    genqemuscript "${fs}"
    "${fs}/qemu.sh" >> "${log}" 2>&1

    # Check the output.
    shopt -s nullglob
    for file in "${fs}/tests/"*.out; do
        local state="$(tail -n 1 "${file}")"
        case "${state}" in
            "Success!") message info "${file##*/} passed!";;
            "Fail!") message warn "${file##*/} failed!";;
            *) message error "${file##*/} did not finish!";;
        esac
    done
}

# Parse the arguments.
CONFIGDIR=""    # Set the initial config dir.
TIMEOUT=10      # Set the default test runner timeout.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        --timeout=*) TIMEOUT="${arg:10}";;
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown arg '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}" "${TIMEOUT}"
