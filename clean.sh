#!/usr/bin/bash
#
# Clean/remove all the old, outdated packages and source tarballs.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"

remove_pkg() {
    # Remove the given package file.
    local file="$1"
    local dry_run="$2"
    message info "Removing outdated file '${file}'"
    if ! "${dry_run}"; then rm "${file}"; fi
}

main() {
    # Remove all the old, outdated packages and source tarballs.
    local configdir="$1"
    local dry_run="$2"

    # Generate a list of the current packages and source tarballs.
    local dir
    local pkgdirs=()
    for dir in "${configdir}/src/"*; do pkgdirs+=("$(basename "${dir}")"); done
    local pkgs=($(printallpkgs "${configdir}" ${pkgdirs[@]}))
    local srctars=($(printallsrctars "${configdir}" ${pkgdirs[@]}))

    # Iterate through all of the built packages, removing any that are not in
    # the list of generated packages.
    local pkgfile pkg
    for pkgfile in "${configdir}/pkgs/"*; do
        local in_list=false
        for pkg in ${pkgs[@]}; do
            if [ "${pkg}" == "${pkgfile}" ]; then
                in_list=true
                break
            fi
        done
        "${in_list}" || remove_pkg "${pkgfile}" "${dry_run}"
    done

    # Iterate through all of the source tarballs, removing any that are not in
    # the list of generated srctars.
    local srctarfile srctar
    for srctarfile in "${configdir}/srctar/"*/*; do
        local in_list=false
        for srctar in "${srctars[@]}"; do
            if [ "${srctar}" == "${srctarfile}" ]; then
                in_list=true
                break
            fi
        done
        "${in_list}" || remove_pkg "${srctarfile}" "${dry_run}"
    done

}

# Parse the arguments.
CONFIGDIR="" # Set the initial config dir.
DRY_RUN="false" # Wether or not to do a dry run.
parseargs "$@" # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        -d|--dry-run) DRY_RUN=true;;
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown extra argument ${arg}!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}" "${DRY_RUN}"
