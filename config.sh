#!/usr/bin/sh
#
# Extract the given variables from the config file.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config file> <var>"
source "$(dirname "$(realpath "$0")")/libmain.sh"
source "$(dirname "$(realpath "$0")")/libbuild.sh"

main() {
    # Sed the var out of the config file.

    local config="$1"
    local var="$2"

    if [ ! -f "${config}" ]; then
        error 1 "'${config}' is not a file!"
    fi

    local lines="$(sed -n -e "/^${var}=.*/p" < "${config}" | wc -l)" 
    if [ "${lines}" -eq 0 ]; then
        error 2 "'${var}' not found in ${config}!"
    elif [ "${lines}" -gt 1 ]; then
        error 2 "'${var}' duplicated in ${config}!"
    fi
    sed -n -e "/^${var}=.*/p" -e "s:^${var}=::" < "${config}"
}

# Parse the arguments.
config="" # The config file.
var="" # The variable to extract. 
parseargs $@ # Initial argument parse.
# Manual argument parse.
for arg in $@; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ "${config}" == "" ]; then
            config="${arg}"
        elif [ "${var}" == "" ]; then
            var="${arg}"
        else
            error 1 "Unknown extra argument '${arg}'!"
        fi;;
    esac
done
if [ -z "${config}" ]; then
    error 1 "A config must be given!"
elif [ -z "${var}" ]; then
    error 1 "A variable must be given!"
fi

main "${config}" "${var}"
