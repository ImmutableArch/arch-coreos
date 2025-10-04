#!/bin/bash

ostree --repo=repo --mode=bare-user init
ostree --repo=repo config set 'core.fsync' 'false'
sudo pacman-ostree compose --ostree-repo=repo --max-layers 92 main.yml image.ociarchive
