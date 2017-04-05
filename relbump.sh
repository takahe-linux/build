#!/usr/bin/bash
#
# Bump the pkgrel of all packages being rebuilt due to an old package
# dependency.
# 
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libbuild.sh"


relbump() {
    # Bump the pkgrel of the given package.
    local configdir="$1"
    local target="$2"

    local dir="${configdir}/src/${target#*/}"

    local pkgrel
    pkgrel="$(sed -n -e '/pkgrel = /p' < "${dir}/.SRCINFO" | \
        sed -e 's:[ \t]*pkgrel = ::')"
    if [ -z "${pkgrel}" ]; then
        error 3 "Could not extract pkgrel for ${dir}"
    fi
    local newrel="$(expr "${pkgrel}" + 1)"

    message warn "Bumping pkgrel for ${target} from ${pkgrel} to ${newrel}"

    sed -i "${dir}/PKGBUILD" -e "s:\(pkgrel=.*\)${pkgrel}:\1${newrel}:"
}

visit_target() {
    # Visit the given target.
    local configdir="$1"
    local target="$2"
    shift 2

    # TODO: This does not work on git packages, since they may have had a
    #       version bump, and it only runs for packages of the same
    #       architecture; this may skip (eg) syslinux when relbumping for mips.

    local state="${targets["${target}"]}"
    case "${state}" in
        good|rebuilt)
            # Ignore rebuilt and good targets.
            message info "Ignoring '${state}' ${target}"
            ;;
        old)
            # For old packages, if they depend on another old package, bump
            # their pkgrel.
            if [ "${target%%/*}" == "pkg" ]; then
                local olddep="false"
                local dep
                for dep in ${graph["${target}"]}; do
                    if [ "${dep%%/*}" == "pkg" ] && \
                        [ "${targets["${dep}"]}" == "old" ]; then
                            olddep="true"
                    fi
                done
                if [ "${olddep}" == "true" ]; then
                    # TODO: This does not work for the case where the package
                    #       itself has had eg a version bump, or the prior
                    #       relbump was interrupted. Perhaps check that we
                    #       have actually built the package as it is?
                    relbump "${configdir}" "${target}"
                else
                    message info "Leaving old ${target}"
                fi
            fi
            ;;
        skip|fail|*)
            # Abort on 'skip' or 'fail' targets - something went wrong...
            # Also abort on anything else.
            error 2 "Target '${target}' has state '${state}'; aborting"
            ;;
        esac
}

main() {
    local configdir="$1"
    walk "${CONFIGDIR}" "visit_target" $(get_target_list "${configdir}")
}

# Parse the arguments.
CONFIGDIR=""        # Set the initial config dir.
parseargs "$@" # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ "${CONFIGDIR}" == "" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown argument '${arg}'"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}"
