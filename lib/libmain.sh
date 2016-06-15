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

# Config file contents.
declare -A config

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
                "${level}" >> /dev/stderr
            exit 1;;
    esac

    # Add a timestamp if debug is set.
    if "${DEBUG}"; then
        fmt="$(date '+%m:%S') ${fmt}"
    fi
    
    # Print the messages if the verboseness is high enough.
    if [ "${VERBOSE}" -ge "${min_level}" ]; then
        printf -- "${fmt}" "$@" >> /dev/stderr
    fi
}

setup() {
    # Check the config directory, load the config file, and create the build 
    # directory.

    local configdir="$@"
    local configfile="${configdir}/config"

    if [ "${configdir}" == "" ]; then
        error 1 "Config dir not given!"
    fi
    for dir in build src pkgs srctar logs; do
        if [ ! -d "${configdir}/${dir}" ]; then
            error 1 "'${configdir}/${dir}' does not exist!"
        fi
    done

    # Check the config file.
    load_config "${configfile}"
    for key in id arch triplet cflags cppflags ldflags qemu-flags; do
        if [ -z "${config["${key}"]}" ]; then
            error 2 "'${key}' is not defined in '${configfile}'!"
        fi
    done
    # Fallback to the value of arch if arch_alias is not given.
    if [ -z "${config[arch_alias]+is_set}" ]; then
        config[arch_alias]="${config[arch]}"
    fi

    # Set the build dir, and create the default directories.
    config[builddir]="${TMPDIR:-/tmp}/builder-${config[id]}/"
    mkdir -p "${config[builddir]}/logs/"
    mkdir -p "${config[builddir]}/cache/"
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

load_config() {
    # Read the contents of the config file.
    local configfile="$1"
    if [ ! -e "${configfile}" ]; then
        error 1 "'${configfile}' does not exist!"
    fi
    local key value

    # We assume that each line is of the form x = y, where x is the
    # variable name and y is the contents.
    while IFS="= $(printf '\t\n')" read key value; do
        config["${key}"]="${value}"
    done < <(sed "${configfile}" -n -e 's:^[ \t]*::' -e '/^[^#]/p')
}
