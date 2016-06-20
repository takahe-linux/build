# Extra shared functions for populating and booting filesystems.

root_own() {
    local mount="$1"
    local file="$2"
    fakeroot chown root "${mount}/${file}"
    fakeroot chgrp root "${mount}/${file}"
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

