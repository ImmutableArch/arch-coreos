FROM docker.io/archlinux/archlinux:latest AS builder

ENV BOOTC_ROOTFS_MOUNTPOINT=/mnt

RUN mkdir -p "${BOOTC_ROOTFS_MOUNTPOINT}/var/lib/pacman"

RUN echo -e "[immutablearch]\nSigLevel = Optional TrustAll\nServer = https://immutablearch.github.io/packages/aur-repo/" \ >> /etc/pacman.conf

RUN pacman -r "${BOOTC_ROOTFS_MOUNTPOINT}" --cachedir=/var/cache/pacman/pkg -Syyuu --noconfirm \
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
  cp /etc/pacman.conf "${BOOTC_ROOTFS_MOUNTPOINT}/etc/pacman.conf" && \
  cp -r /etc/pacman.d "${BOOTC_ROOTFS_MOUNTPOINT}/etc/" && \
  pacman -S --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN pacman -Syu --noconfirm base-devel git rust ostree dracut whois && \
  pacman -S --clean && \
  rm -rf /var/cache/pacman/pkg/*

RUN env \
    KERNEL_VERSION="$(basename "$(find "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/modules" -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" \
    sh -c 'dracut --force -r "${BOOTC_ROOTFS_MOUNTPOINT}" --no-hostonly --reproducible --zstd --verbose --kver "${KERNEL_VERSION}" --add ostree "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"'

RUN cd "${BOOTC_ROOTFS_MOUNTPOINT}" && \
    mkdir -p boot sysroot var/home && \
    rm -rf var/log home root usr/local srv && \
    ln -s /var/home home && \
    ln -s /var/roothome root && \
    ln -s /var/usrlocal usr/local && \
    ln -s /var/srv srv

# Update useradd default to /var/home instead of /home for User Creation
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "${BOOTC_ROOTFS_MOUNTPOINT}/etc/default/useradd"

# Setup a temporary root passwd (changeme) for dev purposes
# TODO: Replace this for a more robust option when in prod
RUN usermod --root "${BOOTC_ROOTFS_MOUNTPOINT}" -p "$(echo "changeme" | mkpasswd -s)" root

# Necessary for `bootc install`
RUN echo -e '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true' | tee "${BOOTC_ROOTFS_MOUNTPOINT}/usr/lib/ostree/prepare-root.conf"

RUN cd "${BOOTC_ROOTFS_MOUNTPOINT}" && \
  mkdir -p sysroot/ostree && \
  ln -s sysroot/ostree ostree

RUN ostree --repo=/repo init --mode=bare-split-xattrs
RUN ostree --repo=/repo commit --orphan --tree=dir="${BOOTC_ROOTFS_MOUNTPOINT}" --bootable

RUN rm /repo/.lock
RUN mv /repo "${BOOTC_ROOTFS_MOUNTPOINT}"/sysroot/ostree/

FROM scratch AS runtime

COPY --from=builder /mnt /

LABEL containers.bootc 1
