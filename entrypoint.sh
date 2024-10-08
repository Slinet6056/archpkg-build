#!/bin/bash

set -e

echo "Starting package build and repository update process..."

pkgname=$1
gpg_private_key=$2
gpg_passphrase=$3
pkg_path=$4
repo_name=$5
repo_path=$6

echo "Input parameters received: pkgname=$pkgname, pkg_path=$pkg_path, repo_name=$repo_name, repo_path=$repo_path"

# Find the PKGBUILD directory
pkgbuild_dir=$(readlink -f "$pkg_path/$pkgname")
echo "PKGBUILD directory: $pkgbuild_dir"

if [[ ! -d $pkgbuild_dir ]]; then
    echo "Error: $pkgbuild_dir should be a directory."
    exit 1
fi

if [[ ! -e $pkgbuild_dir/PKGBUILD ]]; then
    echo "Error: $pkgbuild_dir does not contain a PKGBUILD file."
    exit 1
fi

chown -R builder:builder "$pkgbuild_dir"

echo "Importing GPG key..."
# Import GPG key
if ! sudo -u builder gpg --batch --import <<< "$gpg_private_key"; then
    echo "Error: Failed to import GPG key."
    exit 1
fi
echo "GPG key imported successfully."

# Build package
echo "Building package..."
if ! sudo -u builder bash -c "cd '$pkgbuild_dir' && pikaur -P --noconfirm"; then
    echo "Error: Package build failed."
    exit 1
fi

# Check if package file was created (excluding debug packages)
output_path="/home/builder/.cache/pikaur/pkg"
package_file=$(find "$output_path" -name "${pkgname}-[0-9]*.pkg.tar.zst" ! -name "*-debug-*.pkg.tar.zst" -type f -print -quit)
if [ -z "$package_file" ]; then
    echo "Error: No package file was created during the build process."
    echo "Listing pikaur cache directory contents:"
    ls -la "$output_path"
    exit 1
fi
echo "Package built successfully: $package_file"

# Move package to pkgbuild_dir
mv "$package_file" "$pkgbuild_dir/"
package_file="$pkgbuild_dir/$(basename "$package_file")"
echo "Package moved to: $package_file"

# Sign package (only the non-debug package)
echo "Signing package..."
if ! sudo -u builder bash -c "cd '$pkgbuild_dir' && echo '$gpg_passphrase' | gpg --pinentry-mode loopback --passphrase-fd 0 --detach-sign '$(basename "$package_file")'"; then
    echo "Error: Package signing failed."
    exit 1
fi

# Check if signature file was created
if [ ! -f "${package_file}.sig" ]; then
    echo "Error: Signature file was not created."
    echo "Listing package directory contents:"
    ls -la "$pkgbuild_dir"
    exit 1
fi
echo "Package signed successfully: ${package_file}.sig"

# Check if repo_name and repo_path are provided
if [ -z "$repo_name" ] || [ -z "$repo_path" ]; then
    echo "repo_name or repo_path not provided, skipping package repository update"
    exit 0
fi

# Update the package repository
echo "Updating package repository..."

repodir=$(readlink -f "$repo_path")
mkdir -p "$repodir"
cp "$package_file" "$package_file.sig" "$repodir/"
chown -R builder:builder "$repodir"
echo "Repository directory: $repodir"

if ! sudo -u builder bash -c "
    cd '$repodir'
    repo-add --verify --sign '$repo_name.db.tar.gz' '$package_file'
"; then
    echo "Error: Failed to update package repository."
    echo "Listing current directory contents:"
    ls -la "$repodir"
    exit 1
fi

# Check if database files were created
if [ ! -f "$repodir/$repo_name.db" ] || [ ! -f "$repodir/$repo_name.files" ]; then
    echo "Error: Repository database files were not created."
    echo "Listing current directory contents:"
    ls -la "$repodir"
    exit 1
fi
echo "Package repository updated successfully:"
ls -l "$repodir"

echo "Package build and repository update process completed."
