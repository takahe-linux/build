#!/usr/bin/bash
#
# Create a system image.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -u -e

# TODO: Make the choice of fs type configurable.
MKFS="mkfs.ext2"

# Initial setup.
VERSION="0.1"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"

create_sysimage() {
    # Create the sysimage.
    local path="$1"
    local size="$2"

    if [ -e "${path}" ]; then
        error 2 "'${path}' already exists!"
    elif [ -z "${path}" ]; then
        error 2 "No path given!"
    elif [ ! -d "$(dirname "${path}")" ]; then
        error 2 "Directory for '${path}' does not exist!"
    fi

    qemu-img create -f raw "${path}" "${size}M" || \
        error 1 "Failed to create the image on '${path}'!"
    "${MKFS}" "${path}" || \
        error 1 "Failed to create a filesystem on '${path}'!"
}

# Set the usage string.
USAGE="<image> [size, in MB]"
# Parse the arguments.
SYSIMAGE=""         # Sysimage path.
SYSIMAGE_SIZE=""    # Sysimage size.
parseargs $@ # Initial argument parse.
# Manual argument parse.
for arg in $@; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${SYSIMAGE}" ]; then
            SYSIMAGE="${arg}"
        elif [ -z "${SYSIMAGE_SIZE}" ]; then
            SYSIMAGE_SIZE="${arg}"
        else
            error 1 "Unknown argument '${arg}'!"
        fi;;
    esac
done

create_sysimage "${SYSIMAGE}" "${SYSIMAGE_SIZE:-600}"
