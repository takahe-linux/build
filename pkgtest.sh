#!/usr/bin/bash
#
# Inspect the packages and print any problems.
#
# - Check that the root filesystem only contains the expected paths.
# - Check that no statically linked files are present.
# - Check that some directories are not present
#   (eg /usr/local, /usr/share/info, ...).
# - Check that all symlinks point to files provided by a package.
# - Check that the permissions are sane.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e
shopt -s nullglob

VERSION="0.1"
USAGE="<config dir> [<pkg path> ...]"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"

declare -A symlinks
declare -A files


get_pkgname() {
    # Retrieve the package name from the given directory.
    # The .PKGINFO file is expected to contain the package name.
    local dir="$1"
    /usr/bin/grep "${dir}/.PKGINFO" -e 'pkgname' | cut -d'=' -f2 | \
        sed 's:[ \t]::g'
}

fail_dir() {
    # Record a failure for the given directory.
    local dir="$1"
    local reason="$2"
    message error "$(get_pkgname "${dir}"): ${reason}"
}

fail() {
    # Record a general failure.
    message error "$1"
}

extract_pkg() {
    # Extract the given package.
    local dir="$1"
    local pkg="$(realpath "$2")"

    local pkgname="$(basename "${pkg}")"
    message debug "Extracting package '${pkgname}' into '${dir}'"
    
    pushd "${dir}" > /dev/null
    bsdtar -xf "${pkg}"
    rm -f .MTREE .BUILDINFO
    popd > /dev/null
    message debug "Package extracted"
}

check_root() {
    # Check that the root directory only contains the expected paths.
    local dir="$1"

    message debug "Checking for invalid files in root..."

    local valid valid_filesystem
    declare -A valid=(
        [boot]=""
        [etc]=""
        [usr]=""
        [var]=""
    )

    declare -A valid_filesystem=(
        [boot]=""
        [bin]=""
        [dev]=""
        [etc]=""
        [home]=""
        [mnt]=""
        [proc]=""
        [root]=""
        [sys]=""
        [tmp]=""
        [run]=""
        [usr]=""
        [var]=""
    )

    for i in "${dir}"/*; do
        root_dir="$(basename "${i}")"
        if [ "${valid["${root_dir}"]+set}" != 'set' ]; then
            # Only let filesystem provide some dirs.
            if [ "${valid_filesystem["${root_dir}"]+set}" == 'set' ] && \
                [ "$(get_pkgname "${dir}")" == "filesystem" ]; then
                : # Ignore...
            else
                fail_dir "${dir}" "/${root_dir} exists"
            fi
        fi
    done
}

check_nodirs() {
    # Check that some dirs do not exist.
    local dir="$1"
    message debug "Checking for unwanted dirs..."
    for path in usr/share/info usr/local; do
        if [ -e "${dir}/${path}" ]; then
            fail_dir "${dir}" "Found unwanted path '${path}'"
        fi
    done

    # Fail if a package (except gettext) provides usr/lib/charset.alias.
    if [ -e "${dir}/usr/lib/charset.alias" ] && \
        [ "$(get_pkgname "${dir}")" != "gettext" ]; then
        fail_dir "${dir}" "Found usr/lib/charset.alias!"
    fi
}

check_bin() {
    # Check that there are no invalid binaries or libraries.
    local dir="$1"
    local f="$2"

    # Ignore files in boot/, as they are special.
    if [ "$(printf '%s' "${f}" | cut -d'/' -f1)" == boot ]; then
        return
    fi
    # Ignore *.c32 (syslinux).
    if printf '%s' "${f}" | grep -e '\.c32$' > /dev/null; then
        return
    fi
    # Catch statically linked libraries.
    if printf '%s' "${f}" | grep -e '\.a$' > /dev/null; then
        fail_dir "${dir}" "${f} seems to be a statically linked library!"
    fi

    local readelf arch
    readelf="$(readelf -h -d "${f}" 2> /dev/null)" || true
    arch="$(printf '%s' "${readelf}" | sed -n -e '/Machine:/p' | \
        sed 's/.*:[ \t]*//' | head -n 1)"
    # Check arch.
    if [ -z "${arch}" ]; then
        arch="${global_arch}"
    fi
    if [ -z "${global_arch}" ]; then
        global_arch="${arch}"
    fi
    if [ "${global_arch}" != "${arch}" ]; then
        fail_dir "${dir}" "${f} has arch '${arch}', not '${global_arch}'!"
    fi
    # Check that the binary is stripped.
    # We ignore object files, as they need the symbols.
    local ext="$(printf '%s' "${f}" | rev | cut -d. -f1 | rev)"
    if [ "${ext}" != 'o' ] && [ "${ext}" != 'ko' ]; then
        if file "${f}" | grep 'not stripped' > /dev/null; then
            fail_dir "${dir}" "Found an unstripped file ${f}"
        fi
    fi
}

check_permissions() {
    # Check the permissions for the given file.
    local dir="$1"
    local f="$2"
    perm="$(stat -c "%#a" "${f}")"
    if [ -h "${f}" ]; then
        if [ "${perm}" -ne 0777 ]; then
            fail_dir "${dir}" "Symlink '${f}' has permissions '${perm}'"
        fi 
    elif [ -f "${f}" ]; then
        if [ "${perm}" -ne 0644 ] && [ "${perm}" -ne 0755 ] && \
            [ "${perm}" -ne 0444 ] && [ "${perm}" -ne 0640 ] && \
            [ "${perm}" -ne 0750 ] && [ "${perm}" -ne 0440 ] && \
            [ "${perm}" -ne 0555 ] && [ "${perm}" -ne 0600 ] && \
            [ "${perm}" -ne 0711 ] && [ "${perm}" -ne 0 ]; then
            fail_dir "${dir}" "File '${f}' has permissions '${perm}'"
        fi
    elif [ -d "${f}" ]; then
        if [ "${perm}" -ne 0755 ] && [ "${perm}" -ne 0750 ] && \
            [ "${perm}" -ne 0700 ] && [ "${perm}" -ne 0555 ] && \
            [ "${perm}" -ne 0711 ]; then
            fail_dir "${dir}" "Dir '${f}' has permissions '${perm}'"
        fi
    fi
}

check_file() {
    # Mark the given file.
    local dir="$1"
    local f="$2"
    if target="$(readlink "${f}")"; then
        symlinks["${pkgname}: ${f}"]="${target}"
    fi
    files["${f}"]="${pkgname}"
}

check_pkg() {
    # Check the given directory for suitability.
    local dir="$1"
    local pkg="$2"

    message info "Checking package ${pkgname}..."

    extract_pkg "${dir}" "${pkg}"
    local pkgname="$(get_pkgname "${dir}")" || \
        error 1 "Invalid package '${pkg}!'"

    check_root "${dir}"
    check_nodirs "${dir}"

    # Per-file checks.
    message debug "Checking files for ${pkgname}..."
    pushd "${dir}" > /dev/null
    local f
    find ./ -print0 | while read -r -d '' f; do
        f="$(printf '%s' "${f}" | cut -d/ -f2-)"
        if [ -e "${f}" ]; then
            check_file "${dir}" "${f}"
            check_permissions "${dir}" "${f}"
            check_bin "${dir}" "${f}"
        fi
    done
    popd > /dev/null
}

check_symlinks() {
    # Check that all symlinks are pointing at a file.
    message info "Checking symlinks..."
    local sym target
    for sym in ${!symlinks[@]}; do
        target="${symlinks["${sym}"]}"
        if [ -z "${files["${target}"]}" ]; then
            fail "Found a broken symlink (${sym})"
        fi
    done
}

print_targets() {
    # Print the given path, or all packages if none are passed.
    local configdir="$1"
    shift
    if [ -n "$@" ]; then
        local pkg
        for pkg in "$@"; do
            printf '%s\n' "${pkg}"
        done
    else
        printallpkgs "${configdir}" $(getpkgdirs cross native)
    fi
}

main() {
    # Check the packages.
    local configdir="$1"
    shift
    loadrepoconf "${configdir}"

    local pkg dir
    dir="${config[builddir]}/pkgtest"
    trap "rm -rf '${dir}'" EXIT
    print_targets "${configdir}" "$@" |
    while read pkg; do
        local pkgname="$(basename "${pkg}")"
        rm -rf "${dir}"; mkdir "${dir}"
        check_pkg "${dir}" "${pkg}"
    done
    check_symlinks
    message info "Finished checks!"
}

CONFIGDIR=""    # Set the initial config dir.
PKGS=""         # Packages to check.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        else
            if [ -f "${arg}" ]; then
                PKGS+=" ${arg}"
            else
                error 2 "Package '${arg}' is not a file!"
            fi
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}" "${PKGS}"
