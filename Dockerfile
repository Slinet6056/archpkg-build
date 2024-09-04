FROM archlinux:base-devel

RUN pacman -Syu --noconfirm

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
