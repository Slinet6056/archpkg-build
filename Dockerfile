FROM archlinux:base-devel

RUN pacman -Syu --noconfirm
RUN pacman -S git gnupg --noconfirm

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
