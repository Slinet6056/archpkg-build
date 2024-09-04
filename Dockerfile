FROM archlinux:base-devel

RUN pacman -Syu --noconfirm
RUN pacman -S git gnupg --noconfirm
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
