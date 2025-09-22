#!/bin/bash

set -oue pipefail

INSTALL_DIR="/tmp/rootfs"
mkdir -p ${INSTALL_DIR}/var/lib/pacman

echo -e "[immutablearch]\nSigLevel = Optional TrustAll\nServer = https://immutablearch.github.io/packages/aur-repo/" \ >> /etc/pacman.conf

yes | sudo pacman -Syyu
yes | sudo pacman -S ostree-ext-cli ostree-ext-cli-debug skopeo git rust ostree dracut whois

sudo pacman -r "${INSTALL_DIR}" --cachedir=/var/cache/pacman/pkg -Syyuu --noconfirm \
  base \
  dracut \
  linux \
  linux-firmware \
  ostree \
  grub \
  grub-btrfs \
  ostree-ext-cli \
  ostree-ext-cli-debug \
  bootc-git \
  bootupd-git \
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
  crun \
  netavark \
  skopeo \
  dbus \
  dbus-glib \
  glib2 \
  pacman \
  shadow && \
  cp /etc/pacman.conf "${INSTALL_DIR}/etc/pacman.conf" && \
  cp -r /etc/pacman.d "${INSTALL_DIR}/etc/" && \
  pacman -S --clean && \
  rm -rf /var/cache/pacman/pkg/*

env \
    KERNEL_VERSION="$(basename "$(find "${INSTALL_DIR}/usr/lib/modules" -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" \
    sh -c 'dracut --force -r "${INSTALL_DIR}" --no-hostonly --reproducible --zstd --verbose --kver "${KERNEL_VERSION}" --add ostree "${INSTALL_DIR}/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"'

rm -rf ${INSTALL_DIR}/boot
cd "${INSTALL_DIR}" && \
    mkdir -p boot sysroot var/home && \
    rm -rf var/log home root usr/local srv && \
    ln -s var/home home && \
    ln -s var/roothome root && \
    ln -s var/usrlocal usr/local && \
    ln -s var/srv srv

sed -i 's|^HOME=.*|HOME=/var/home|' "${INSTALL_DIR}/etc/default/useradd"

echo -e '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true' | tee "${INSTALL_DIR}/usr/lib/ostree/prepare-root.conf"

cd "${INSTALL_DIR}" && \
    mkdir -p sysroot/ostree && \
    ln -s sysroot/ostree ostree

ostree --repo=/repo init --mode=bare-user
ostree --repo=/repo commit --branch=immutablearch/x86_64/arch-coreos --bootable --tree=dir=${INSTALL_DIR}
rm /repo/.lock
mv /repo ${INSTALL_DIR}/ostree

ostree-ext-cli container encapsulate --repo=/repo immutablearch/x86_64/arch-coreos oci-archive:/tmp/image.tar
