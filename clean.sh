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

main() {
    # Remove all the old, outdated packages and source tarballs.
    local configdir="$1"

    # Iterate through all of the packages.
    local srctar srctarprefix pkg pkgprefix file
    for dir in "${configdir}/src/"*/*; do
        # Remove all outdated versions of this package.

        if [ ! -d "${dir}" ] || [ ! -f "${dir}/PKGBUILD" ]; then
            # Bail early if this is not a valid package dir.
            continue
        fi
        local pkgdir="$(printf "%s" "${dir}" | rev | cut -d'/' -f1-2 | rev)"

        # We need a .SRCINFO - generate it if it does not exist.
        # TODO: Implement.
        
        # Find the expected names; iterate through the existing srctars and
        # packages and remove all that match the package's name, but not the
        # version.
        srctar="$(pkgdirsrctar "${configdir}" "${pkgdir}")" || \
            error 1 "Failed to generate the source tarball name for '${pkgdir}'!"
        srctarprefix="$(printf "%s" "${srctar}" | rev | cut -d'-' -f3- | rev)"
        for file in "${configdir}/srctar/${srctarprefix}"-[0-9]*-*"${SRCEXT}"; do
            if [ "${file##*/}" != "${srctar}" ] && [ -f "${file}" ]; then
                # Remove this; it is an outdated source tarball.
                message info "Removing outdated file '${file}'"
                rm "${file}"
            fi
        done

        # Iterate through the packages.
        while IFS="-" read pkg; do
            pkgprefix="$(printf "%s" "${pkg}" | rev | cut -d'-' -f4- | rev)"
            for file in "${configdir}/pkgs/${pkgprefix}"-[0-9]*-*-*"${PKGEXT}"; do
                if [ "${file##*/}" != "${pkg}" ] && [ -f "${file}" ]; then
                    # Remove this; it is an outdated package.
                    message info "Removing outdated file '${file}'"
                    rm "${file}"
                fi
            done
        done < <(pkgdirpackages "${configdir}" "${pkgdir}") || \
            error 1 "Failed to generate a list of packages for '${pkgdir}'!"
    done
}

# Parse the arguments.
CONFIGDIR="" # Set the initial config dir.
parseargs "$@" # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown extra argument ${arg}!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}"
