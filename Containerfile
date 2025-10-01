FROM docker.io/archlinux/archlinux:latest AS builder

ENV BOOTC_ROOTFS_MOUNTPOINT=/mnt

RUN echo -e "[immutablearch]\nSigLevel = Optional TrustAll\nServer = https://immutablearch.github.io/packages/aur-repo/" \ >> /etc/pacman.conf

RUN mkdir -p "${BOOTC_ROOTFS_MOUNTPOINT}/var/lib/pacman"

RUN pacman -r "${BOOTC_ROOTFS_MOUNTPOINT}" --cachedir=/var/cache/pacman/pkg -Syyuu --noconfirm \
  base \
  dracut \
  linux \
  linux-firmware \
  ostree \
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
  conmon \
  bootc-git \
  bootupd-git \
  grub \
  grub-btrfs \
  crun \
  netavark \
  skopeo \
  dbus \
  dbus-glib \
  glib2 \
  pacman \
  shadow && \
  cp /etc/pacman.conf "${BOOTC_ROOTFS_MOUNTPOINT}/etc/pacman.conf" && \
  cp -r /etc/pacman.d "${BOOTC_ROOTFS_MOUNTPOINT}/etc/" && \
  pacman -S --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN pacman -Syu --noconfirm base-devel git rust ostree ostree-ext-cli ostree-ext-cli-debug skopeo dracut whois && \
  pacman -S --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN env \
    KERNEL_VERSION="$(basename "$(find "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/modules" -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" \
    sh -c 'dracut --force -r "${BOOTC_ROOTFS_MOUNTPOINT}" --no-hostonly --reproducible --zstd --verbose --kver "${KERNEL_VERSION}" --add ostree "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"'


#RUN cp -v ${BOOTC_ROOTFS_MOUNTPOINT}/boot/*.img ${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/modules/${KERNEL_VERSION}/


RUN rm -rf "${BOOTC_ROOTFS_MOUNTPOINT}"/boot

RUN cd "${BOOTC_ROOTFS_MOUNTPOINT}" && \
    mkdir -p boot sysroot var/home && \
    rm -rf var/log home root usr/local srv && \
    ln -s /var/home home && \
    ln -s /var/roothome root && \
    ln -s /var/usrlocal usr/local && \
    ln -s /var/srv srv && \
    mkdir sysroot/ostree && \
    ln -s sysroot/ostree ostree

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "${BOOTC_ROOTFS_MOUNTPOINT}/etc/default/useradd"

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
#RUN usermod --root "${BOOTC_ROOTFS_MOUNTPOINT}" -p "$(echo "changeme" | mkpasswd -s)" root

# Necessary for `bootc install`
RUN echo -e '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true' | tee "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/ostree/prepare-root.conf"

RUN ostree --repo=/repo init --mode=bare-user
RUN ostree --repo=/repo commit --branch=immutablearch/x86_64/arch-coreos --bootable --no-xattrs --disable-fsync --tree=dir=${BOOTC_ROOTFS_MOUNTPOINT}
RUN ostree --repo=/repo ls immutablearch/x86_64/arch-coreos
RUN ostree --repo=/repo ls immutablearch/x86_64/arch-coreos | sort | uniq -d
RUN rm /repo/.lock
RUN ostree-ext-cli container encapsulate --repo=/repo immutablearch/x86_64/arch-coreos oci-archive:/tmp/image.ociarchive
RUN ls /tmp

#LABEL containers.bootc 1
