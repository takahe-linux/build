#!/usr/bin/sh
#
# Library functions for utilities.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >


# Define some colors.
# Alternative start appears to be '\x1b['
C_ERR="\033[31;1m"
C_WARN="\033[33;1m"
C_OK="\033[32;1m"
C_BOLD="\033[39;1m"
C_RESET="\033[39;0m"

# Default verboseness.
export VERBOSE="${VERBOSE:-1}"
# Debug flag.
export DEBUG="${DEBUG:-false}"

error() {
    local status="$1"
    shift
    message error "$@"
    exit "${status}"
}

message() {
    local level="$1"
    shift

    local fmt="%s\n"
    local min_level="0"

    case "${level}" in
        debug) fmt="DBG %s\n"
            min_level="2";;
        info) fmt="${C_OK}-->${C_RESET} %s\n"
            min_level="1";;
        warn) fmt="${C_WARN}>>>${C_RESET} %s\n";;
        error) fmt="${C_ERR}!!!${C_BOLD} %s${C_RESET}\n";;
        *) printf "${C_ERR}BUG${C_RESET} Unknown message format '%s'!\n" \
                "${level}" > /dev/stderr
            exit 1;;
    esac

    # Add a timestamp if debug is set.
    if "${DEBUG}"; then
        fmt="$(date '+%m:%S') ${fmt}"
    fi
    
    # Print the messages if the verboseness is high enough.
    if [ "${VERBOSE}" -ge "${min_level}" ]; then
        printf "${fmt}" "$@" > /dev/stderr
    fi
}

check_configdir() {
    # Check the configuration directory.

    local configdir="$@"
    local configfile="${configdir}/config"

    if [ "${configdir}" == "" ]; then
        error 1 "Config dir not given!"
    fi
    for dir in build logs src pkgs srctar; do
        if [ ! -d "${configdir}/${dir}" ]; then
            error 1 "'${configdir}/${dir}' does not exist!"
        fi
    done
    if [ ! -e "${configfile}" ]; then
        error 1 "'${configfile}' does not exist!"
    fi

}

ignore_arg() {
    # Whether or not to ignore the given arg (it will be handled by parseargs).

    case "$1" in
        --|-q|--quiet|-d|--debug) return 0;;
    esac
    return 1
}

parseargs() {
    # Do a simple run through of the arguments.

    for arg in $@; do
        case "${arg}" in
            --) return;;
            -q|--quiet) export VERBOSE="0";;
            -d|--debug) export DEBUG="true"; export VERBOSE="2";;
            -\?|-h|--help) echo "$0 [-?|-h|--help] [-v|--version] ${USAGE}"
                exit 0;;
            -v|--version) echo "$(basename "$0") - ${VERSION}"
                exit 0;;
        esac
    done
}

config() {
    # Extract a given variable from the config file.

    var="$2"
    source "$1"
    eval "printf '$2'"
}
