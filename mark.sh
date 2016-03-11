#!/usr/bin/bash
# 
# Mark the given target as up to date.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir> <target>"
source "$(dirname "$(realpath "$0")")/libmain.sh"
source "$(dirname "$(realpath "$0")")/libbuild.sh"

# Parse the arguments.
CONFIGDIR="" # Set the initial config dir.
TARGET="" # Set the target to mark.
parseargs $@ # Initial argument parse.
# Manual argument parse.
for arg in $@; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        elif [ "${TARGET}" == "" ]; then
            TARGET="${arg}"
        else
            error 1 "Unknown argument '${arg}'"
        fi;;
    esac
done
check_configdir "${CONFIGDIR}"

if [ "${TARGET}" == "" ]; then
    error 1 "No target given!"
fi

generate_graph "${CONFIGDIR}" "${TARGET}"
generate_states "${CONFIGDIR}"

mark "${CONFIGDIR}" "${TARGET}" || \
    error $? "Invalid target '${TARGET}'"
