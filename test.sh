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

    loadrepoconf "${configdir}"

    local fs="${config[builddir]}/tests"
    local log="${config[builddir]}/logs/test.log"
    mkdir -p "${fs}/var/lib/pacman"

    # Generate the list of packages and install them.
    message info "Populating test environment..."
    callpacman "${fs}" --needed --arch "${config[arch]}" \
        -U $(printallpkgs "${configdir}" $(getpkgdirs packages native)) \
        > "${log}" 2>&1

    # Add the initial scripts.
    gendefhostname "${fs}"

    # Generate the test runner.
    rm -rf "${fs}/tests"
    mkdir "${fs}/tests"
    cat > "${fs}/etc/init/run" << EOF
#!/usr/bin/sh
# Test runner.
trap 'poweroff -f' EXIT # Ensure that we shutdown.
for file in /tests/*; do
    if [ "\${file: -5}" == ".test" ]; then
        out="\${file::-5}.out"
        rm -f "\${out}"
        touch "\${out}"
        timeout -t ${timeout} "\${file}" >> "\${out}"
        err="\$?"
        if [ "\$err" -gt 127 ]; then
            echo "Timeout: exit code '\${err}'" >> "\${out}"
        fi
    fi
done
EOF
    chmod +x "${fs}/etc/init/run"

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
    message info "Results:"
    shopt -s nullglob
    for file in "${fs}/tests/"*.out; do
        local state="$(tail -n 1 "${file}")"
        case "${state}" in
            'Success!') message info "${file##*/}: passed";;
            'Fail!') message error "${file##*/}: failed!";;
            Timeout:*) message warn "${file##*/}: timed out!";;
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
