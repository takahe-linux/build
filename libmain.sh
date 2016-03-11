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
    local output="true"

    case "${level}" in
        debug) fmt="DBG %s\n";;
        info) fmt="${C_OK}-->${C_RESET} %s\n";;
        warn) fmt="${C_WARN}>>>${C_RESET} %s\n";;
        error) fmt="${C_ERR}!!!${C_BOLD} %s${C_RESET}\n";;
        *) print "${C_ERR}BUG${C_RESET} Unknown message format '${level}'!\n" \
                > /dev/stderr
            exit 1;;
    esac
    
    if "${output}"; then
        printf "${fmt}" "$@" > /dev/stderr
    fi
}

check_configdir() {
    # Check the configuration directory.

    local configdir="$@"
    local configfile="${configdir}/config.sh"
    local builddir="${configdir}/build/"
    local pkgdir="${configdir}/pkgs/"

    if [ "${configdir}" == "" ]; then
        error 1 "Config dir not given!"
    fi
    for dir in "${configdir}" "${builddir}" "${pkgdir}"; do
        if [ ! -d "${dir}" ]; then
            error 1 "'${dir}' does not exist!"
        fi
    done
    if [ ! -e "${configfile}" ]; then
        error 1 "$(printf "${template}" "${configfile}")"
    fi

}

parseargs() {
    # Do a simple run through of the arguments.

    for arg in $@; do
        case "${arg}" in
            --) break;;
            -?|-h|--help) echo "$0 [-?|-h|--help] [-v|--version] ${USAGE}"
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
