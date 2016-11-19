#!/usr/bin/bash
#
# Populate a given system image.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e -u

# Initial setup.
VERSION="0.2"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"
source "$(dirname "$(realpath "$0")")/lib/libboot.sh"

populate_sysimage() {
    # Install the packages to the system image.
    local configdir="$1"
    local sysimage="$2"
    local fs="$3"
    shift 3

    loadrepoconf "${configdir}"
    
    # Prepare the mountpoint.
    point="$(mktemp -d "${TMPDIR:-/tmp}/mount.XXXX")" || \
        error 1 "Failed to make a temporary dir to mount '${sysimage}' on!"
    cleanup="rm -rf '${point}'"; trap "${cleanup}" EXIT
    mount "${sysimage}" "${point}" || \
        error 1 "Failed to mount the system image!"
    cleanup="umount '${point}' && ${cleanup}"; trap "${cleanup}" EXIT
    mkdir -p "${point}/var/lib/pacman" || \
        error 1 "Failed to create '${point}/var/lib/pacman'!"
    # Install the packages.
    installpkglist "${configdir}" "${point}" qemu "$@"

    # Add the initial scripts.
    bash -c "printf 'qemu\n' > '${point}/etc/hostname'"
    cat > "${point}/etc/init.d/run" << EOF
#!/usr/bin/sh
/usr/bin/getty -l /usr/bin/login 0 /dev/console
EOF
    chmod +x "${point}/etc/init.d/run"
}

# Set the usage string.
USAGE="<configdir> [--fs=<fs type>] <image> [extra packages ...]"
# Parse the arguments.
CONFIGDIR=""        # Config dir.
SYSIMAGE=""         # Sysimage path.
FS="ext2"           # Filesystem type.
EXTRA=""        # Extra packages to install.
parseargs $@ # Initial argument parse.
# Manual argument parse.
for arg in $@; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        --fs=*) FS="${arg:5}";;
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        elif [ -z "${SYSIMAGE}" ]; then
            SYSIMAGE="${arg}"
        else
            EXTRA+=" ${arg}"
        fi;;
    esac
done
setup "${CONFIGDIR}"
if [ ! -f "${SYSIMAGE}" ]; then
    error 1 "'${SYSIMAGE}' is not a file!"
fi

populate_sysimage "${CONFIGDIR}" "${SYSIMAGE}" "${FS}" ${EXTRA}
