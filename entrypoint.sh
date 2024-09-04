#!/bin/bash

set -e

pkgname=$1
gpg_private_key=$2
gpg_passphrase=$3

# Create builder user
useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

# Find the PKGBUILD directory
pkgbuild_dir=$(readlink -f "$pkgname")

if [[ ! -d $pkgbuild_dir ]]; then
    echo "$pkgbuild_dir should be a directory."
    exit 1
fi

if [[ ! -e $pkgbuild_dir/PKGBUILD ]]; then
    echo "$pkgbuild_dir does not contain a PKGBUILD file."
    exit 1
fi

# Fix directory permissions
chown -R builder:builder "$pkgbuild_dir"
chown -R builder:builder /home/builder

# Import GPG key
echo "$gpg_private_key" | sudo -u builder gpg --import
echo "$gpg_passphrase" | sudo -u builder gpg --batch --passphrase-fd 0 --pinentry-mode loopback -s /dev/null

# Build package
cd "$pkgbuild_dir"
sudo -u builder bash <<EOF
export GPG_TTY=\$(tty)
echo "$gpg_passphrase" | gpg --batch --passphrase-fd 0 --pinentry-mode loopback -s /dev/null
makepkg -srf --sign --noconfirm
EOF

cd -
