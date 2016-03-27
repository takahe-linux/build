# Package manipulation functions.

# Standardise the source and package name extensions.
PKGEXT='.pkg.tar.xz'
SRCEXT='.src.tar.gz'

callmakepkg() {
    # Call makepkg locally.
    local configdir="$(realpath "$1")"
    local prefix="$2"
    local path="$3"
    shift 3

    pushd "${path}" > /dev/null || \
        exit 1
    # Create the log file, if needed.
    if [ -z "${LOGFILE}" ]; then
        local log="$(mktemp "${TMPDIR:-/tmp}/makepkglog.XXXXXXXX")" || \
            error 1 "Failed to make the temporary log file!"
        cleanup+="rm -f '${log}'; "
        trap "${cleanup}" EXIT
    else
        local log="${LOGFILE}"
    fi

    # Generate the config file.
    # We can't use a here-document because that gets lost somewhere when
    # makepkg uses fakechroot.
    local makepkgconf="$(mktemp "${TMPDIR:-/tmp}/makepkgconf.XXXXXXXX")" || \
        error 1 "Failed to make the makepkgconf temporary file!"
    cleanup+="rm -f '${makepkgconf}'; "
    trap "${cleanup}" EXIT
    genmakepkgconf "${configdir}" "${prefix}" > "${makepkgconf}"

    # Run makepkg.
    makepkg --config "${makepkgconf}" "$@" 2> "${log}" > "${log}"
    # Bail as appropriate...
    local status="$?"
    if [ "${status}" -ne 0 ]; then
        # Print the log and exit.
        message error "makepkg failed! last 50 lines of log:"
        tail -n 50 "${log}" > /dev/stderr
        exit "${status}"
    fi

    # Clean up.
    ${cleanup}
    popd > /dev/null
}

genmakepkgconf() {
    # Print an suitable makepkg.conf.
    # TODO: This should override some variables, sanitize others, etc...
    #       which it clearly doesn't.
    local configdir="$1"
    local prefix="$2"
    cat << EOF
source "${configdir}/src/${prefix}/makepkg.conf"
SRCPKGDEST="${configdir}/srctar"
PKGDEST="${configdir}/pkgs"
LOGDEST="${configdir}/logs"
PKGEXT='${PKGEXT}'
SRCEXT='${SRCEXT}'
EOF
}

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
    
    printf "${pkgbase}-${pkgver}-${pkgrel}.src.tar.gz"
}

pkgdirpackages() {
    # Use makepkg to print the resulting filenames of the given packages.
    local configdir="$1"
    local pkgdir="$2"

    # Bail if there is no .SRCINFO
    srcinfo="${configdir}/src/${pkgdir}/.SRCINFO"
    if [ ! -f "${srcinfo}" ]; then
        exit 2
    fi
    # Extract the pkgbase/version/rel/arch
    local pkgbase="$(sed -n "${srcinfo}" -e '/^pkgbase = /p' | \
        sed -e 's:.*= ::')"
    local pkgver="$(sed -n "${srcinfo}" -e '/pkgver = /p' | sed -e 's:.*= ::')"
    local pkgrel="$(sed -n "${srcinfo}" -e '/pkgrel = /p' | sed -e 's:.*= ::')"
    local arch="$(sed -n "${srcinfo}" -e '/arch = /p' | sed -e 's:.*= ::')"

    # Source the makepkg.conf.
    # We need this for both PKGEXT and the expected architecture.
    . "${configdir}/src/${pkgdir}/../makepkg.conf"

    # We just report one package.
    # TODO: Report all packages, and better handle the various corner cases.
    # I did try using makepkg --packagelist, but it was *painfully* slow...
    if [ "${arch}" != "any" ]; then
        local carch="${CARCH}"
    else
        local carch="any"
    fi
    printf "${pkgbase}-${pkgver}-${pkgrel}-${carch}${PKGEXT}"
}
