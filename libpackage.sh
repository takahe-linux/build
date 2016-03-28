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

    pushd "${path}" > /dev/null || exit 1
    # Generate the config file.
    # We can't use a here-document because that gets lost somewhere when
    # makepkg uses fakeroot.
    local makepkgconf="$(mktemp "${TMPDIR:-/tmp}/makepkgconf.XXXXXXXX")" || \
        error 1 "Failed to make the makepkgconf temporary file!"
    trap "rm -f '${makepkgconf}'" EXIT
    genmakepkgconf "${configdir}" "${prefix}" > "${makepkgconf}"

    # Run makepkg.
    makepkg --config "${makepkgconf}" "$@" || exit "$?"

    # Clean up.
    rm -f "${makepkgconf}"
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
