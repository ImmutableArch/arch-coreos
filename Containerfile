FROM docker.io/archlinux:latest

RUN sed -i -e 's|^NoExtract.*||g' /etc/pacman.conf
RUN echo -e "[immutablearch]\nSigLevel = Optional TrustAll\nServer = https://immutablearch.github.io/packages/aur-repo/" \ >> /etc/pacman.conf

RUN pacman -Sy --noconfirm \
  dracut \
  linux \
  linux-firmware \
  ostree \
  bootc \
  bootupd \
  btrfs-progs \
  e2fsprogs \
  xfsprogs \
  grub \
  grub-btrfs \
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
  shadow && \
  pacman -S --clean --clean && \
  rm -rf /var/cache/pacman/pkg/*



RUN echo "$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)")" > kernel_version.txt && \
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$(cat kernel_version.txt)" --add ostree "/usr/lib/modules/$(cat kernel_version.txt)/initramfs.img" && \
    rm kernel_version.txt

RUN mkdir -p /boot /sysroot /var/home && \
    rm -rf /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

RUN sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

COPY files/ostree/prepare-root.conf /usr/lib/ostree/prepare-root.conf

LABEL ostree.bootable="true"
LABEL containers.bootc 1
