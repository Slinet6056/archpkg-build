#!/bin/bash

set -e
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Cleanup function to securely remove sensitive data
cleanup() {
    local exit_code=$?
    echo "Performing cleanup..."

    # Securely remove GPG keys from memory and keyring
    if sudo -u builder gpg --list-keys &>/dev/null; then
        sudo -u builder gpg --batch --yes --delete-secret-and-public-keys --fingerprint 2>/dev/null || true
    fi

    # Clean GPG agent
    sudo -u builder gpgconf --kill gpg-agent 2>/dev/null || true

    # Shred temporary GPG files if they exist
    if [ -d "/home/builder/.gnupg" ]; then
        find /home/builder/.gnupg -type f -exec shred -vfz -n 3 {} \; 2>/dev/null || true
    fi

    exit $exit_code
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Validation function
validate_inputs() {
    if [ -z "$pkgname" ]; then
        echo "Error: package_name is required but not provided."
        exit 1
    fi

    if [ -z "$gpg_private_key" ]; then
        echo "Error: gpg_private_key is required but not provided."
        exit 1
    fi

    if [ -z "$gpg_passphrase" ]; then
        echo "Error: gpg_passphrase is required but not provided."
        exit 1
    fi
}

echo "Starting package build and repository update process..."

pkgname=$1
gpg_private_key=$2
gpg_passphrase=$3
pkg_path=${4:-.}  # Default to current directory if not provided
repo_name=${5:-}
repo_path=${6:-}

# Validate required inputs
validate_inputs

# Log parameters (without sensitive data)
echo "Input parameters received: pkgname=$pkgname, pkg_path=$pkg_path, repo_name=${repo_name:-<not set>}, repo_path=${repo_path:-<not set>}"

# Find the PKGBUILD directory
pkgbuild_dir=$(readlink -f "$pkg_path/$pkgname")
echo "PKGBUILD directory: $pkgbuild_dir"

if [[ ! -d "$pkgbuild_dir" ]]; then
    echo "Error: PKGBUILD directory not found at: $pkgbuild_dir"
    echo "Available directories in $pkg_path:"
    ls -la "$pkg_path" || echo "Failed to list directory contents"
    exit 1
fi

if [[ ! -f "$pkgbuild_dir/PKGBUILD" ]]; then
    echo "Error: PKGBUILD file not found in: $pkgbuild_dir"
    echo "Directory contents:"
    ls -la "$pkgbuild_dir" || echo "Failed to list directory contents"
    exit 1
fi

# Set proper permissions
chown -R builder:builder "$pkgbuild_dir"

echo "Importing GPG key..."
# Import GPG key with better error handling
if ! sudo -u builder gpg --batch --yes --import <<< "$gpg_private_key" 2>&1 | grep -i "imported\|not changed"; then
    echo "Error: Failed to import GPG key. Please verify the key format."
    exit 1
fi

# Get GPG key fingerprint for verification
gpg_fingerprint=$(sudo -u builder gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')
if [ -z "$gpg_fingerprint" ]; then
    echo "Error: Failed to retrieve GPG key fingerprint."
    exit 1
fi
echo "GPG key imported successfully. Fingerprint: $gpg_fingerprint"

# Test GPG signing capability
echo "test" | sudo -u builder bash -c "echo '$gpg_passphrase' | gpg --pinentry-mode loopback --passphrase-fd 0 --batch --yes --default-key '$gpg_fingerprint' --clearsign" > /dev/null 2>&1 || {
    echo "Error: GPG key test signing failed. Please verify the passphrase."
    exit 1
}
echo "GPG key verification successful."

# Build package
echo "Building package..."
if ! sudo -u builder bash -c "cd '$pkgbuild_dir' && pikaur -P --noconfirm" 2>&1; then
    echo "Error: Package build failed."
    echo "Please check the PKGBUILD file and build dependencies."
    exit 1
fi

# Check if package file was created (excluding debug packages)
output_path="/home/builder/.cache/pikaur/pkg"
if [ ! -d "$output_path" ]; then
    echo "Error: Pikaur cache directory not found at: $output_path"
    exit 1
fi

package_file=$(find "$output_path" -name "${pkgname}-[0-9]*.pkg.tar.zst" ! -name "*-debug-*.pkg.tar.zst" -type f -print -quit)
if [ -z "$package_file" ]; then
    echo "Error: No package file was created during the build process."
    echo "Expected package pattern: ${pkgname}-[0-9]*.pkg.tar.zst"
    echo "Listing pikaur cache directory contents:"
    ls -laR "$output_path" 2>&1 || echo "Failed to list directory"
    exit 1
fi
echo "Package built successfully: $(basename "$package_file")"

# Move package to pkgbuild_dir
if ! mv "$package_file" "$pkgbuild_dir/"; then
    echo "Error: Failed to move package file to build directory."
    exit 1
fi
package_file="$pkgbuild_dir/$(basename "$package_file")"
echo "Package moved to: $package_file"

# Sign package (only the non-debug package)
echo "Signing package..."
if ! sudo -u builder bash -c "cd '$pkgbuild_dir' && echo '$gpg_passphrase' | gpg --pinentry-mode loopback --passphrase-fd 0 --batch --yes --default-key '$gpg_fingerprint' --detach-sign '$(basename "$package_file")'" 2>&1; then
    echo "Error: Package signing failed."
    echo "Package file: $(basename "$package_file")"
    exit 1
fi

# Check if signature file was created
if [ ! -f "${package_file}.sig" ]; then
    echo "Error: Signature file was not created."
    echo "Expected signature file: ${package_file}.sig"
    echo "Listing package directory contents:"
    ls -la "$pkgbuild_dir"
    exit 1
fi
echo "Package signed successfully: $(basename "${package_file}.sig")"

# Check if repo_name and repo_path are provided
if [ -z "$repo_name" ] || [ -z "$repo_path" ]; then
    echo "repo_name or repo_path not provided, skipping package repository update"
    echo "Package build and signing completed successfully."
    exit 0
fi

# Update the package repository
echo "Updating package repository..."

repodir=$(readlink -f "$repo_path")
if ! mkdir -p "$repodir"; then
    echo "Error: Failed to create repository directory: $repodir"
    exit 1
fi

if ! cp "$package_file" "$package_file.sig" "$repodir/"; then
    echo "Error: Failed to copy package files to repository directory."
    exit 1
fi

chown -R builder:builder "$repodir"
echo "Repository directory: $repodir"

# Update repository database
if ! sudo -u builder bash -c "
    cd '$repodir' && \
    repo-add --verify --sign --key '$gpg_fingerprint' '$repo_name.db.tar.gz' '$(basename "$package_file")'
" 2>&1; then
    echo "Error: Failed to update package repository."
    echo "Repository name: $repo_name"
    echo "Package file: $(basename "$package_file")"
    echo "Listing repository directory contents:"
    ls -la "$repodir"
    exit 1
fi

# Verify database files were created
if [ ! -f "$repodir/$repo_name.db" ]; then
    echo "Error: Repository database file was not created: $repo_name.db"
    echo "Listing repository directory contents:"
    ls -la "$repodir"
    exit 1
fi

if [ ! -f "$repodir/$repo_name.files" ]; then
    echo "Error: Repository files database was not created: $repo_name.files"
    echo "Listing repository directory contents:"
    ls -la "$repodir"
    exit 1
fi

echo "Package repository updated successfully."
echo "Repository contents:"
ls -lh "$repodir"

echo "Package build and repository update process completed successfully."
