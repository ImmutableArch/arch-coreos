FROM archlinux:latest

RUN echo -e "[immutablearch]\nSigLevel = Optional TrustAll\nServer = https://immutablearch.github.io/packages/aur-repo/" \ >> /etc/pacman.conf
# Update system and install packages
RUN pacman -Syu --noconfirm && \
    pacman -Sy --noconfirm \
        dracut \
        linux \
        linux-firmware \
        ostree \
        ostree-ext-cli \
        ostree-ext-cli-debug \
        composefs \
        systemd \
        btrfs-progs \
        e2fsprogs \
        xfsprogs \
        udev \
        cpio \
        zstd \
        binutils \
        dosfstools \
        bootc-git \
        bootupd-git \
        conmon \
        crun \
        netavark \
        skopeo \
        dbus \
        dbus-glib \
        glib2 \
        grub \
        grub-btrfs \
        shadow && \
        rm -rf /var/cache/pacman/pkg/*

# Update Initramfs (dracut)
RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)" --add ostree "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm kernel_version.txt


# Modify filesystem to be compatiable with ostree
RUN mv /home /var/
RUN ln -s var/home /home

RUN mv /mnt /var/
RUN ln -s var/mnt /mnt

RUN rmdir /var/opt
RUN mv /opt /var/
RUN ln -s var/opt /opt

RUN mv /root /var/roothome
RUN ln -s var/roothome /root

RUN mv /srv /var/srv
RUN ln -s var/srv /srv

COPY ostree-0-integration.conf /usr/lib/tmpfiles.d/

RUN bootc container lnit
RUN ostree-ext-cli container commit

LABEL ostree.bootable="true"
LABEL containers.bootc 1
