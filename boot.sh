#!/usr/bin/bash
#
# Create and boot a filesystem with all of the available packages installed.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"
source "$(dirname "$(realpath "$0")")/lib/libboot.sh"

main() {
    # Generate the fs and boot.
    local configdir="$1"
    shift

    loadrepoconf "${configdir}"

    local fs="${config[builddir]}/fs"
    mkdir -p "${fs}/var/lib/pacman"

    # Generate the list of packages and install them.
    callpacman "${fs}" --needed --arch "${config[arch]}" \
        -U $(printallpkgs "${configdir}" $(getpkgdirs cross native))

    # Add the initial scripts.
    gendefhostname "${fs}"
    cat > "${fs}/etc/init/run" << EOF
#!/usr/bin/sh
/usr/bin/getty -l /usr/bin/login 0 /dev/console
EOF
    chmod +x "${fs}/etc/init/run"

    # Install the utilities.
    for file in "${configdir}/src/util/"*; do
        install -m0755 "${file}" "${fs}/usr/bin/"
    done

    # Run qemu and exit.
    genqemuscript "${fs}"
    "${fs}/qemu.sh"
}

# Parse the arguments.
CONFIGDIR=""    # Set the initial config dir.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown arg '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}"
