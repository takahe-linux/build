#!/usr/bin/bash
#
# Populate a given system image.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e -u

# Initial setup.
VERSION="0.1"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"

populate_sysimage() {
    # Install the packages to the system image.
    local configdir="$1"
    local sysimage="$2"
    
    # Prepare the mountpoint.
    point="$(sudo mktemp -d "${TMPDIR:-/tmp}/mount.XXXX")" || \
        error 1 "Failed to make a temporary dir to mount '${sysimage}' on!"
    cleanup="sudo rm -rf '${point}'"; trap "${cleanup}" EXIT
    sudo mount "${sysimage}" "${point}" || \
        error 1 "Failed to mount the system image!"
    cleanup="sudo umount '${point}' && ${cleanup}"; trap "${cleanup}" EXIT
    sudo mkdir -p "${point}/var/lib/pacman"
    # Install the packages.
    sudo pacman --arch "${config[arch]}" --root "${point}" \
        -U "${configdir}/pkgs"/*{"${config[arch]}",any}.pkg.tar.*

    # Add a basic fstab.
    # TODO: If the fs is configurable, this will need adjusting.
    sudo tee "${point}/etc/fstab" > /dev/null << EOF
/dev/sda / ext2 rw,relatime,noatime,data=ordered 0 1
devtmpfs devtmpfs /dev
procfs procfs /proc
sysfs sysfs /sys
tmpfs tmpfs /tmp
EOF
    
    # Add the hostname.
    echo 'qemu' | sudo tee "${point}/etc/hostname" > /dev/null
}

# Set the usage string.
USAGE="<configdir> <image>"
# Parse the arguments.
CONFIGDIR=""        # Config dir.
SYSIMAGE=""         # Sysimage path.
parseargs $@ # Initial argument parse.
# Manual argument parse.
for arg in $@; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        elif [ -z "${SYSIMAGE}" ]; then
            SYSIMAGE="${arg}"
        else
            error 1 "Unknown argument '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"
if [ ! -f "${SYSIMAGE}" ]; then
    error 1 "'${SYSIMAGE}' is not a file!"
fi

populate_sysimage "${CONFIGDIR}" "${SYSIMAGE}"
