FROM archlinux:base-devel

# Update package database only (not full system upgrade) and install essential packages
# This reduces build time and image size while keeping dependencies current
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed git && \
    # Clean package cache to reduce image size
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Create builder user with sudo privileges
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Setup GPG directory with correct permissions
RUN mkdir -p /home/builder/.gnupg && \
    chown -R builder:builder /home/builder/.gnupg && \
    chmod 700 /home/builder/.gnupg

# Install pikaur as builder user and clean up
RUN su - builder -c "\
    git clone --depth=1 https://aur.archlinux.org/pikaur.git && \
    cd pikaur && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -rf pikaur" && \
    # Clean up package cache after pikaur installation
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /home/builder/.cache/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
