# Extra shared functions for populating and booting filesystems.

root_own() {
    local mount="$1"
    local file="$2"
    fakeroot chown root "${mount}/${file}"
    fakeroot chgrp root "${mount}/${file}"
}

genfstab() {
    # TODO: Put this in a package.
    local mount="$1"
    local file="etc/fstab"
    cat > "${mount}/${file}" << EOF
# fstab - basic filesystem mounts
devtmpfs    dev     /dev
proc        proc    /proc
sysfs       sys     /sys
tmpfs       tmp     /tmp
EOF
}

geninitscript() {
    # Generate the default init scripts.
    # TODO: Put this in a package.
    local mount="$1"
    local run="$2" # The command to run once started.

    # Add the default init script.
    local file="etc/init/init"
    mkdir -p "${mount}/etc/init/"
    cat > "${mount}/${file}" << EOF
#!/usr/bin/bash

# Setup.
# We mount these manually because mount -a doesn't seem to.
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -a
hostname -F /etc/hostname
# TODO: This should be fixed in the dev init.
ln -s /proc/self/fd /dev/fd

# Start the given script.
${run} &

# Wait, then poweroff.
wait
poweroff -f
EOF
    chmod +x "${mount}/${file}"
    root_own "${mount}" "${file}"

    # Add the default shutdown script.
    local file="etc/init/shutdown"
    mkdir -p "${mount}/etc/init/"
    cat > "${mount}/${file}" << EOF
#!/usr/bin/sh
# TODO: Kill/wait for remaining services.
poweroff -f
EOF
    chmod +x "${mount}/${file}"
    root_own "${mount}" "${file}"

}

gendefhostname() {
    # Generate the default hostname.
    local mount="$1"
    local file="etc/hostname"
    printf "qemu\n" > "${mount}/${file}"
    root_own "${mount}" "${file}"
}

genqemuscript() {
    # Generate the QEMU script.
    local mount="$1"
    if [ "$#" -gt 1 ]; then
        local mem="$2"
    else
        # Default to some small value.
        local mem=24
    fi
    local tag="root"
    cat > "${mount}/qemu.sh" << EOF
#!/usr/bin/sh
fakeroot "qemu-system-${config[arch_alias]}" "\$@" \
    -kernel "${mount}/boot/vmlinuz" \
    -append "console=ttyS0 init=/usr/bin/sinit panic=1 rootfstype=9p rw rootflags=trans=virtio,version=9p2000.L" \
    -fsdev local,id=${tag},security_model=none,path=${mount} \
    -device virtio-9p-pci,fsdev=${tag},mount_tag=/dev/root \
    -m "${mem}" \
    -no-reboot -nographic
exit "\$?"
EOF
    chmod +x "${mount}/qemu.sh"
}

