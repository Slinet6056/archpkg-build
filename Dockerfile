FROM archlinux:base-devel

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm git && \
    useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    mkdir -p /home/builder/.gnupg && \
    chown -R builder:builder /home/builder/.gnupg && \
    chmod 700 /home/builder/.gnupg && \
    su - builder -c "git clone https://aur.archlinux.org/pikaur.git && cd pikaur && makepkg -si --noconfirm" && \
    rm -rf /home/builder/pikaur

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
