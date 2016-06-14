# Package manipulation functions.

# Standardise the source and package name extensions.
PKGEXT='.pkg.tar.xz'
SRCEXT='.src.tar.gz'

pkgdirsrctar() {
    # Print the source tarball path for the given package dir.
    local configdir="$1"
    local pkgdir="$2"
    
    # Bail if there is no .SRCINFO
    srcinfo="${configdir}/src/${pkgdir}/.SRCINFO"
    if [ ! -f "${srcinfo}" ]; then
        exit 2
    fi
    # Extract the pkgbase/version/rel
    pkgbase="$(sed -n "${srcinfo}" -e '/^pkgbase = /p' | sed -e 's:.*= ::')"
    pkgver="$(sed -n "${srcinfo}" -e '/pkgver = /p' | sed -e 's:.*= ::')"
    pkgrel="$(sed -n "${srcinfo}" -e '/pkgrel = /p' | sed -e 's:.*= ::')"
    
    printf "%s-%s-%s%s" "${pkgbase}" "${pkgver}" "${pkgrel}" "${SRCEXT}"
}

pkgdirpackages() {
    # Print the resulting filenames of the given packages.
    # makepkg --packagelist is slow, so use the .SRCINFO instead.
    local configdir="$1"
    local pkgdir="$2"

    # Bail if there is no .SRCINFO
    srcinfo="${configdir}/src/${pkgdir}/.SRCINFO"
    if [ ! -f "${srcinfo}" ]; then
        exit 2
    fi
    # Extract the pkgbase/version/rel/arch
    local pkgnames="$(sed -n "${srcinfo}" -e '/^pkgname = /p' | \
        sed -e 's:.*= ::')"
    local pkgver="$(sed -n "${srcinfo}" -e '/pkgver = /p' | sed -e 's:.*= ::')"
    local pkgrel="$(sed -n "${srcinfo}" -e '/pkgrel = /p' | sed -e 's:.*= ::')"
    local arch="$(sed -n "${srcinfo}" -e '/arch = /p' | sed -e 's:.*= ::')"

    # Set the CARCH variable to the current architecture.
    local CARCH="$(uname -m)"
    # Set some other expected variables from the config.
    . <(genmakepkgconf "${configdir}" "${pkgdir}") || \
        error 1 "Failed to generate a temporary config file!"

    if [ "${arch}" != "any" ]; then
        local carch="${CARCH}"
    else
        local carch="any"
    fi
    for pkgname in ${pkgnames}; do
        printf "%s-%s-%s-%s%s\n" "${pkgname}" "${pkgver}" "${pkgrel}" \
            "${carch}" "${PKGEXT}"
    done
}

localmakepkgconf() {
    # Write the current main makepkg.conf to stdout.

    cat /etc/makepkg.conf

    local localconf="${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf"
    if [ -f "${localconf}" ]; then
        cat "${localconf}"
    fi

    if [ -f "${HOME}/.makepkg.conf" ]; then
        cat "${HOME}/.makepkg.conf"
    fi
}

genmakepkgconf() {
    # Write a temporary config script to stdout.
    local configdir="$1"
    local pkgdir="${2%%/*}"

    local outfile="${config[builddir]}/cache/makepkgconf-${pkgdir}"
    if [ ! -f "${outfile}" ]; then
        message debug "Generating makepkgconf for '${pkgdir}'..."
        if [ ! -d "${outfile%/*}" ]; then
            mkdir -p "${outfile%/*}"
        fi

        # Extract PACKAGER and MAKEFLAGS from the local makepkg.conf.
        printf '# Local configs\n' > "${outfile}"
        localmakepkgconf | /usr/bin/grep -e '^PACKAGER=' -e '^MAKEFLAGS=' \
            >> "${outfile}"

        # Print a 'config.sh' equivalent.
        # We also standardise PKGEXT and SRCEXT.
        printf '
# Standard config variables.
_target_arch="%s"
_target_arch_alias="%s"
_target_triplet="%s"
_local_triplet="${CHOST}"
_target_cflags="%s"
_target_cppflags="%s"
_target_ldflags="%s"

# Sysroot is hardcoded to /sysroot.
_sysroot=/sysroot
_toolroot="/opt/${_target_triplet}"

# We standardise PKGEXT.
PKGEXT="%s"
SRCEXT="%s"

# Set BUILDDIR to something sane.
BUILDDIR="%s"
' \
            "${config[arch]}" "${config[arch_alias]}" "${config[triplet]}" \
            "${config[cflags]}" "${config[cppflags]}" "${config[ldflags]}" \
            "${PKGEXT}" "${SRCEXT}" "${config[builddir]}" >> "${outfile}"

        # If a package config file exists, add it...
        local local_config="${configdir}/src/${pkgdir}/makepkg.conf"
        if [ -f "${local_config}" ]; then
            cat "${local_config}" >> "${outfile}"
        fi
    fi

    cat "${outfile}"
}

findpkgdir() {
    # Given a package name and dir, find all packages in that dir that provide
    # the given package name.
    local configdir="$1"
    local target_name="$2"
    local dir="$3"

    local pkg providers provdir provider
    while IFS=":" read pkg providers; do
        if [ "${pkg}" == "${target_name}" ]; then
            while IFS="\/ " read provdir provider; do
                if [ "${provdir}" == "${dir}" ]; then
                    printf "%s/%s\n" "${provdir}" "${provider}"
                fi
            done < <(printf "${providers}\n")
        fi
    done < "${configdir}/pkglist"
}

findpkgdeps() {
    # Evaluate the deps piped in on stdin to dirs.
    local configdir="$1"
    local prefix="$2"
    local deptype dep
    while IFS="= $(printf '\t\n')" read deptype dep; do
        if [ -z "${dep}" ]; then
            continue
        fi
        local depdir skip_missing
        if [ "${deptype}" == "hostdepends" ] || \
            [ "${deptype}" == "checkdepends" ]; then
            # We treat checkdepends as host dependencies.
            depdirs="toolchain"
            host_missing="true"
        elif [ "${prefix}" == "toolchain" ] && \
            [ "${deptype}" != "targetdepends" ]; then
            depdirs="toolchain"
            host_missing="true"
        elif [ "${prefix}" == "packages" ]; then
            depdirs="packages"
            host_missing="false"
        else
            depdirs="native packages"
            host_missing="false"
        fi
        for depdir in ${depdirs}; do
            local providers="$(findpkgdir "${configdir}" "${dep}" \
                "${depdir}")" \
                || error 3 "Failed to get providers for '${dep}'!"
            if [ -n "${providers}" ]; then
                # Break early if we have found at least one provider.
                break
            fi
        done
        # Check that we did find a provider.
        if [ -z "${providers}" ]; then
            if [ "${host_missing}" == "false" ]; then
                error 4 "Found no providers for '${dep}' of type '${deptype}'!"
            else
                # We use a "fake" host package instead.
                printf "%s host/%s\n" "${dep}" "${dep}"
            fi
        elif [ -n "${providers}" ]; then
            printf "%s %s\n" "${dep}" "${providers}"
        fi
    done < /dev/stdin
}

checkprov() {
    # Fail if there are too many providers.
    dep="$1"
    shift
    if [ "$(printf "%s\n" "$@" | wc -l)" -gt 1 ]; then
        error 1 "Too many providers found for '${dep}': $@"
    elif [ -z "$1" ]; then
        error 1 "No providers found for '${dep}'!"
    fi
}

installdeps() {
    local configdir="$1"
    local target="$2"
    local basedir="$3"

    # Keep track of the dependencies corresponding to the various dirs.
    local tooldepends crossdepends nativedepends
    declare -a tooldepends
    declare -a crossdepends
    declare -a nativedepends

    # Declare the vars for the graph traversal.
    local visited stack
    declare -A visited
    declare -a stack

    # Initialise the stack and visited hash.
    # We cannot just put the target on the stack, as it has a different
    # dependency generation script, and should not end up in *depends.
    local deps
    deps="$("$(dirname "$0")/../../scripts/lsdeps.sh" \
        <(genmakepkgconf "${configdir}" "${target}") \
        "${configdir}/src/${target}/PKGBUILD")" || \
        error 1 "Failed to extract the deps from the PKGBUILD!"
    local dep prov
    while IFS=" " read dep prov; do
        checkprov "${dep}" "${prov}"
        if [ -z "${visited["${prov}"]+is_set}" ]; then
            visited["${prov}"]="${dep}"
            stack+=("${prov}")
        fi
    done < <(printf "%s\n" "${deps}" | \
        findpkgdeps "${configdir}" "${target%%/*}") || \
        error 3 "Failed to generate the package providers!"

    # Traverse the graph.
    while [ "${#stack}" -gt 0 ]; do
        # Visit each node.

        # Pop the item off the top of the stack.
        local current="${stack[-1]}"
        stack=(${stack[@]:0:$(expr "${#stack[@]}" - 1)})

        # Add the item to the appropriate list.
        case "${current%%/*}" in
            toolchain) tooldepends+=("${current}");;
            packages) crossdepends+=("${current}");;
            native) nativedepends+=("${current}");;
            host) # For host dependencies, we don't need to recurse.
                tooldepends+=("${current}")
                continue;;
            *) error 2 "Unknown provider prefix '${current%%/*}'!"
        esac

        # Process the dependencies.
        local dep prov
        while IFS=" " read dep prov; do

            message debug "${current} requires ${prov}"
            checkprov "${dep}" "${prov}"

            # If the provider is unvisited, add it to the stack and mark it
            # as visited.
            if [ -z "${visited["${prov}"]+is_set}" ]; then
                visited["${prov}"]="${dep}"
                stack+=("${prov}")
            fi
        done < <(sed "${configdir}/src/${current}/.SRCINFO" -n \
            -e '/^[ \t]*depends = /p' | \
            findpkgdeps "${configdir}" "${current%%/*}") || \
            error 3 "Failed to generate the package providers!"
    done

    # Install the dependencies.
    installtooldeps "${configdir}" "${target%%/*}" "${basedir}" \
        "${tooldepends[@]}"
    installcrossdeps "${configdir}" "${target%%/*}" "${basedir}" \
        "${crossdepends[@]}"
    installnativedeps "${configdir}" "${target%%/*}" "${basedir}" \
        "${nativedepends[@]}"
}

callpacman() {
    # Call pacman on the given sysroot.
    local args="$@"
    message debug "Running pacman with args '--noconfirm --root ${args}'"
    fakechroot fakeroot pacman --noconfirm --root "$@" || \
        error 1 "Failed to run pacman on the root!"
}

mappkgs() {
    # Map the given dirs to actual packages.
    # TODO: Currently, we do not preserve the actual package names, so this is
    #       overly enthusiastic in the case of split packages.
    local configdir="$1"
    shift
    local targ pkg
    for targ in "$@"; do
        pkgdirpackages "${configdir}" "${targ}" | \
            while IFS= read pkg; do
                printf "%s/pkgs/%s\n" "${configdir}" "${pkg}"
            done || \
                error 2 "Failed to map '${targ}' to corresponding packages!"
    done
}

installtooldeps() {
    # Install the given list of host deps.
    # Fall back to the host packages if no matching packages are found.
    local configdir="$1"
    local prefix="$2"
    local basedir="$3"
    shift 3
    if [ "$#" -eq 0 ] && [ "${prefix}" != "packages" ]; then return; fi

    if [ "${prefix}" == "native" ]; then
        error 1 "Cannot install host deps to a native root!"
    fi

    # Figure out which packages are host packages and which are tool deps.
    local pkg hostdeps toolchaindeps
    declare -a hostdeps
    declare -a toolchaindeps
    for pkg in "$@"; do
        if [ "${pkg%%/*}" == "host" ]; then
            hostdeps+=("${pkg##*/}")
        else
            toolchaindeps+=("${pkg}")
        fi
    done
    # We always install base-devel.
    # TODO: Can I cache this instead? Is the RAM cost worth it?
    hostdeps+=('base-devel')

    message info "Installing toolchain packages to ${basedir}:"
    for i in ${toolchaindeps[@]} ${hostdeps[@]}; do message info "    $i"; done

    # Initialise the pacman sync databases.
    mkdir -p "${basedir}/var/lib/pacman" && \
        fakeroot cp -p -r /var/lib/pacman/sync "${basedir}/var/lib/pacman" || \
        error 1 "Failed to copy the host sync databases!"

    # Install base-devel.
    if [ "${#hostdeps}" -gt 0 ]; then
        callpacman "${basedir}" --cachedir /var/cache/pacman/pkg -S \
            ${hostdeps[@]}
    fi
    
    # Install the given packages.
    if [ "${#toolchaindeps}" -gt 0 ]; then
        callpacman "${basedir}" --cachedir /var/cache/pacman/pkg -U \
            $(mappkgs "${configdir}" "${toolchaindeps[@]}")
    fi
}

installcrossdeps() {
    # Install the given list of cross compiled deps.
    local configdir="$1"
    local prefix="$2"
    local basedir="$3"
    shift 3
    if [ "$#" -eq 0 ]; then return; fi

    if [ "${prefix}" == "native" ]; then
        local root="${basedir}"
    else
        local root="${basedir}/sysroot/"
    fi

    message info "Installing cross compiled packages to ${root}:"
    for i in "${@}"; do message info "    $i"; done

    # Set up the root.
    if [ ! -d "${root}/var/lib/pacman" ]; then
        mkdir -p "${root}/var/lib/pacman"
    fi

    # Install the given packages.
    callpacman "${root}" --arch "${config[arch]}" \
        -U $(mappkgs "${configdir}" "${@}")
}

installnativedeps() {
    # Install the given list of native deps.
    local configdir="$1"
    local prefix="$2"
    local basedir="$3"
    shift 3
    if [ "$#" -eq 0 ]; then return; fi

    if [ "${prefix}" != "native" ]; then
        error 1 "Cannot install native deps to a non-native root!"
    fi

    message info "Installing native packages to ${basedir}:"
    for i in "$@"; do message info "    $i"; done

    # Set up the root.
    if [ ! -d "${basedir}/var/lib/pacman" ]; then
        mkdir -p "${basedir}/var/lib/pacman"
    fi

    # Install the given packages.
    callpacman "${basedir}" --arch "${config[arch]}" \
        -U $(mappkgs "${configdir}" "$@")
}

