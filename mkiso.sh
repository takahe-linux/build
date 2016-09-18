#!/usr/bin/bash
#
# Create a bootable cdrom.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e

# Initial setup.
VERSION="0.1"
USAGE="<config dir> <iso file>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"
source "$(dirname "$(realpath "$0")")/lib/libboot.sh"

# We overwrite the next two functions from lib/libpackage.sh and
# lib/libboot.sh, as we want to run everything as root to avoid possible
# permission issues.
root_own() {
    local mount="$1"
    local file="$2"
    chown root "${mount}/${file}"
    chgrp root "${mount}/${file}"
}
callpacman() {
    pacman --noconfirm --root "$@"
}

main() {
    # Generate the fs and boot.
    local configdir="$1"
    local iso="$2"
    shift

    loadrepoconf "${configdir}"

    # Check that we are root (needed to avoid permissions issues).
    if [ "$(whoami)" != root ]; then
        error 1 "We need to be root!"
    fi

    local fs="${config[builddir]}/iso"
    rm -rf "${fs}"
    mkdir -p "${fs}/var/lib/pacman"

    # Install the packages.
    installpkglist "${configdir}" "${fs}" cdrom

    # We assume syslinux; set it up.
    local filename
    for filename in "${fs}/usr/lib/syslinux/bios/"*.c32; do
        cp "${filename}" \
            "${fs}/boot/syslinux/$(basename "${filename}")"
    done
    cat > "${fs}/boot/syslinux/syslinux.cfg" << EOF
DEFAULT linux
PROMPT 0
TIMEOUT 50
UI menu.c32
MENU TITLE Takahe Linux
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL linux
    MENU LABEL Takahe Linux
    LINUX ../vmlinuz
    APPEND root=/dev/sr0 ro init=/usr/bin/sinit panic=10

LABEL hdt
    MENU LABEL HDT (Hardware Detection Tool)
    COM32 hdt.c32

LABEL reboot
    MENU LABEL Reboot
    COM32 reboot.c32

LABEL poweroff
    MENU LABEL Poweroff
    COM32 poweroff.c32
EOF
    root_own "${fs}" "boot/syslinux/syslinux.cfg"

    # Generate the hostname.
    printf 'takahe\n' > "${fs}/etc/hostname"
    root_own "${fs}" 'etc/hostname'

    # Generate an empty fstab.
    : > "${fs}/etc/fstab"
    root_own "${fs}" 'etc/fstab'

    # Add the init scripts.
    cat > "${fs}/etc/init/run" << EOF
#!/usr/bin/sh
/usr/bin/getty -l /usr/bin/login 0 /dev/console
EOF
    chmod +x "${fs}/etc/init/run"
    root_own "${fs}" 'etc/init/run'

    # Create a repo on the CDROM, for ease of access.
    install -dm0755 "${fs}/repo"
    cp "${configdir}/pkgs/"* "${fs}/repo/"

    # Generate the iso.
    # We need -rock (rock ridge extensions) and -no-emul-boot to let us have
    # extended permissions and such exotic things as symlinks!
    message info "Creating the iso..."
    mkisofs -b 'usr/lib/syslinux/bios/isolinux.bin' \
        -c 'usr/lib/syslinux/bios/boot.cat' \
        -boot-load-size 4 -boot-info-table \
        -rock -no-emul-boot "${fs}" > "${iso}" || \
        error 3 "Failed to generate the iso!"

    message info "Created iso '${iso}'!"
    message info "To burn the image to a cd, run"
    message info "# cdrecord dev=/dev/cdrom -v -sao '${iso}'"
    message info "where -sao is replaced by -tao or similar if required"

    # Clean up...
    rm -rf "${fs}"
}

# Parse the arguments.
CONFIGDIR=""    # Set the initial config dir.
ISOFILE=""      # Set the iso file.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        elif [ -z "${ISOFILE}" ]; then
            ISOFILE="${arg}"
        else
            error 1 "Unknown arg '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"
if [ -z "${ISOFILE}" ]; then
    error 2 "No iso file specified!"
fi

main "${CONFIGDIR}" "${ISOFILE}"

