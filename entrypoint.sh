#!/bin/bash

set -e

pkgname=$1
gpg_private_key=$2
gpg_passphrase=$3
pkg_path=$4
repo_name=$5
repo_path=$6

# Find the PKGBUILD directory
pkgbuild_dir=$(readlink -f "$pkg_path/$pkgname")

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
echo "$gpg_private_key" | gpg --batch --import
EOF

# Build package
sudo -u builder bash <<EOF
cd "$pkgbuild_dir"
makepkg -srf --noconfirm
EOF

# Sign package
sudo -u builder bash <<EOF
cd "$pkgbuild_dir"
echo "$gpg_passphrase" | gpg --pinentry-mode loopback --passphrase-fd 0 --detach-sign *.pkg.tar.zst
EOF

# Check if repo_name and repo_path are provided
if [ -z "$repo_name" ] || [ -z "$repo_path" ]; then
    echo "repo_name or repo_path not provided, skipping package repository update"
    exit 0
fi

repodir=$(readlink -f "$repo_path")
mkdir -p "$repodir"
chown -R builder:builder "$repodir"

# Update the package repository
sudo -u builder bash <<EOF
cp "$pkgbuild_dir"/*.pkg.tar.zst* "$repodir"
cd "$repodir"
repo-add --verify --sign "$repo_name.db.tar.gz" *.pkg.tar.zst
EOF
