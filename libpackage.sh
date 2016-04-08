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
    # I did try using makepkg --packagelist, but it was *painfully* slow...
    # TODO: Figure out how to use makepkg --packagelist.
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

    # Source the makepkg.conf to find the expected architecture.
    . /etc/makepkg.conf
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

genmakepkgconf() {
    # Write a temporary config script to stdout.
    local configdir="$1"
    local pkgdir="$2"

    # Print a 'config.sh' equivalent.
    # We also standardise PKGEXT and SRCEXT.
    printf '
# Standard config variables.
_target_arch="%s"
_target_arch_alias="${_target_arch}" # TODO: partial name (i586->i386)
_target_triplet="%s"
_local_triplet="${CHOST}"
_target_cflags="%s"
_target_ldflags="%s"

# Sysroot is hardcoded to /sysroot.
_sysroot=/sysroot
_toolroot="/opt/${_target_triplet}"

# We standardise PKGEXT.
PKGEXT="%s"
SRCEXT="%s"
' \
        "${config[arch]}" "${config[triplet]}" "${config[cflags]}" \
        "${config[ldflags]}" "${PKGEXT}" "${SRCEXT}"

    # If a package config file exists, add it...
    local local_config="${configdir}/src/${pkgdir%%/*}/makepkg.conf"
    if [ -f "${local_config}" ]; then
        cat "${local_config}"
    fi
}
