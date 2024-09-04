#!/bin/bash

set -e

pkgname=$1
gpg_private_key=$2
gpg_passphrase=$3
pkgdir=$4

# Find the PKGBUILD directory
pkgbuild_dir=$(readlink -f "$pkgdir/$pkgname")

if [[ ! -d $pkgbuild_dir ]]; then
    echo "$pkgbuild_dir should be a directory."
    exit 1
fi

if [[ ! -e $pkgbuild_dir/PKGBUILD ]]; then
    echo "$pkgbuild_dir does not contain a PKGBUILD file."
    exit 1
fi

# Create builder user
useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
mkdir -p /home/builder/.gnupg
chown -R builder:builder /home/builder/.gnupg
chmod 700 /home/builder/.gnupg
chown -R builder:builder "$pkgbuild_dir"

# Import GPG key
sudo -u builder bash <<EOF
export HOME=/home/builder
echo "$gpg_private_key" | gpg --batch --import
EOF

# Build package
sudo -u builder bash <<EOF
cd "$pkgbuild_dir"
makepkg -srf --noconfirm
EOF

# Sign package
sudo -E -u builder bash <<EOF
export HOME=/home/builder
cd "$pkgbuild_dir"
echo "$gpg_passphrase" | gpg --pinentry-mode loopback --passphrase-fd 0 --detach-sign *.pkg.tar.zst
EOF
