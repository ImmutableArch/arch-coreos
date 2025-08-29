FROM archlinux:latest

ENV PACMAN_NO_CONFIRM=1
ENV OSTREE_REPO=/ostree/repo
ENV ROOTFS=/tmp/rootfs

# 1. Aktualizacja systemu + pacstrap + ostree
RUN pacman -Syu --noconfirm base base-devel git wget curl archlinux-keyring arch-install-scripts ostree

# 2. Utworzenie repo OSTree
RUN mkdir -p $OSTREE_REPO && \
    ostree --repo=$OSTREE_REPO init --mode=archive

RUN echo -e "[aur-repo]\nSigLevel = Optional TrustAll\nServer = https://immutable-arch.github.io/packages/aur-repo/" \
    >> /etc/pacman.conf

# 3. Utworzenie tymczasowego rootfs
RUN mkdir -p $ROOTFS && \
    pacstrap -c -C /etc/pacman.conf --ignoreMounts $ROOTFS base linux dracut ostree bootc-git bootupd-git

# 4. Commit rootfs do OSTree (branch: arch-coreod)
RUN ostree --repo=$OSTREE_REPO commit \
    --branch=arch-coreos \
    --tree=dir=$ROOTFS \
    --subject="Arch-coreos base system"

# 5. Sprzątanie
RUN rm -rf $ROOTFS

# 6. Oznacz obraz jako ostree-container (dla bootc)
RUN ostree container commit
