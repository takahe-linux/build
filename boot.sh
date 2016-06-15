#!/usr/bin/bash
#
# Create and boot a filesystem with all of the available packages installed.
#
# Author:   Alastair Hughes
# Contact:  < hobbitalastair at yandex dot com >

set -e

# Initial setup.
VERSION="0.1"
USAGE="<config dir>"
source "$(dirname "$(realpath "$0")")/lib/libmain.sh"
source "$(dirname "$(realpath "$0")")/lib/libpackage.sh"

root_own() {
    local fs="$1"
    local file="$2"
    fakeroot chown root "${fs}/${file}"
    fakeroot chgrp root "${fs}/${file}"
}

main() {
    # Generate the fs and boot.
    # TODO: This duplicates a lot; clean up!
    # TODO: Merge with mksysimage.
    local configdir="$1"
    shift

    fs="${config[builddir]}/fs"
    mkdir -p "${fs}/var/lib/pacman"

    # Generate the list of packages and install them.
    message info "Finding packages..."
    local pkgs=()
    local dir name generate pkg
    for dir in "${configdir}/src/packages"/* "${configdir}/src/native"/*; do
        name="$(printf '%s' "${dir}" | rev | cut -d'/' -f1-2 | rev)"
        if [ -d "${dir}" ] && [ -f "${dir}/.SRCINFO" ]; then
            generate="$(pkgdirpackages "${configdir}" "${name}")" || \
                error 1 "Failed to generate the packages for '${name}'!"
            for pkg in ${generate}; do
                if [ -e "${configdir}/pkgs/${pkg}" ]; then
                    pkgs+=("${configdir}/pkgs/${pkg}")
                else
                    message warn "Could not find package file '${pkg}'!"
                fi
            done
        fi
    done

    message info "Installing packages: ${pkgs[@]}"
    sudo pacman --arch "${config[arch]}" --root "${fs}" --needed --noconfirm \
        -U ${pkgs[@]}

    # Add a basic fstab.
    local file="etc/fstab"
    cat > "${fs}/${file}" << EOF
# fstab - basic filesystem mounts
proc proc /proc
sysfs sys /sys
tmpfs tmp /tmp
EOF
    root_own "${fs}" "${file}"

    # Add the default hostname.
    local file="etc/hostname"
    printf "qemu\n" > "${fs}/${file}"
    root_own "${fs}" "${file}"

    # Add the default init script.
    local file="etc/init/init"
    mkdir -p "${fs}/etc/init/"
    cat > "${fs}/${file}" << EOF
#!/usr/bin/bash

# Setup.
mount -a &
hostname -F /etc/hostname

# Start a couple of gettys.
/usr/bin/getty 19800 /dev/console &
/usr/bin/getty 19800 /dev/tty1 &

# Wait, then poweroff.
# TODO: Make this more flexible.
wait
wait
wait
poweroff -f
EOF
    chmod +x "${fs}/${file}"
    root_own "${fs}" "${file}"

    # Add the default shutdown script.
    local file="etc/init/shutdown"
    mkdir -p "${fs}/etc/init/"
    cat > "${fs}/${file}" << EOF
#!/usr/bin/sh
poweroff -f
EOF
    chmod +x "${fs}/${file}"
    root_own "${fs}" "${file}"

    # Generate the qemu script.
    local tag="dev"
    local mem=24
    cat > "${fs}/qemu.sh" << EOF
#!/usr/bin/sh
fakeroot "qemu-system-${config[arch_alias]}" "\$@" \
    -kernel "${fs}/boot/vmlinuz" \
    -append "console=ttyS0 init=/usr/bin/sinit panic=1 rootfstype=9p rw rootflags=trans=virtio,version=9p2000.L" \
    -fsdev local,id=${tag},security_model=none,path=${fs} \
    -device virtio-9p-pci,fsdev=${tag},mount_tag=/dev/root \
    -m "${mem}" \
    -no-reboot -nographic
exit "\$?"
EOF
    chmod +x "${fs}/qemu.sh"
    
    # Run qemu and exit.
    "${fs}/qemu.sh"
}

# Parse the arguments.
CONFIGDIR=""    # Set the initial config dir.
parseargs "$@"  # Initial argument parse.
# Manual argument parse.
for arg in "$@"; do
    ignore_arg "${arg}" || \
    case "${arg}" in
        *) if [ -z "${CONFIGDIR}" ]; then
            CONFIGDIR="${arg}"
        else
            error 1 "Unknown arg '${arg}'!"
        fi;;
    esac
done
setup "${CONFIGDIR}"

main "${CONFIGDIR}"
