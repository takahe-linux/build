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
    . /etc/makepkg.conf
    . "${configdir}/src/config.sh"
    if [ -f "${configdir}/src/${pkgdir}/../makepkg.conf" ]; then
        . "${configdir}/src/${pkgdir}/../makepkg.conf"
    fi

    # We just report one package.
    # TODO: Report all packages, and better handle the various corner cases.
    # I did try using makepkg --packagelist, but it was *painfully* slow...
    if [ "${arch}" != "any" ]; then
        local carch="${CARCH}"
    else
        local carch="any"
    fi
    printf "%s-%s-%s-%s%s" "${pkgbase}" "${pkgver}" "${pkgrel}" "${carch}" \
        "${PKGEXT}"
}
