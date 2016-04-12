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
    
    point="$(sudo mktemp -d "${TMPDIR:-/tmp}/mount.XXXX")" || \
        error 1 "Failed to make a temporary dir to mount '${sysimage}' on!"
    cleanup="sudo rm -rf '${point}'"; trap "${cleanup}" EXIT
    sudo mount "${sysimage}" "${point}" || \
        error 1 "Failed to mount the system image!"
    cleanup="sudo umount '${point}' && ${cleanup}"; trap "${cleanup}" EXIT
    sudo mkdir -p "${point}/var/lib/pacman"
    sudo pacman --arch "${config[arch]}" --root "${point}" \
        -U "${configdir}/pkgs"/*"${config[arch]}.pkg.tar".*
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
check_configdir "${CONFIGDIR}"
if [ ! -f "${SYSIMAGE}" ]; then
    error 1 "'${SYSIMAGE}' is not a file!"
fi

populate_sysimage "${CONFIGDIR}" "${SYSIMAGE}"
