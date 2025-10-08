FROM public.ecr.aws/docker/library/python:3.14-slim-trixie

LABEL name="calibre-with-kfx" maintainer="yshalsager <contact@yshalsager.com>"
LABEL org.opencontainers.image.description="An image for running Calibre with KFX support to allow conversion of KFX files to other formats."

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Calibre deps
    ca-certificates curl gnupg2 xz-utils \
    # X11 runtime deps
    libx11-6 libxext6 libxrender1 libxi6 libxcursor1 libxinerama1 libxfixes3 \
    # QTWebEngine
    libxdamage1 libxrandr2 libxtst6 \
    # for kindle support
    xvfb xauth libgl1 libgl1-mesa-dri libdrm2 libgbm1 \
    libegl1 libopengl0 libxkbcommon-x11-0 libxcomposite1 \
    # calibre 7
    libxcb-cursor0 \
    && install -d -m 1777 /tmp/.X11-unix \
    && rm -rf /var/lib/apt/lists/*

# Install wine
ARG WINE_BRANCH="staging"
RUN dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && curl -fsSLo /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && curl -fsSLo /etc/apt/sources.list.d/winehq-trixie.sources https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends winbind winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# Install calibre
RUN curl -fsSL https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin

ARG USERNAME=calibre
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir /app && chown -R $USERNAME:$USERNAME /app \
    && install -d -m 700 -o $USER_UID -g $USER_GID /run/user/$USER_UID
USER calibre

# Set XDG runtime dir for the non-root user
ENV XDG_RUNTIME_DIR=/run/user/1000

# Calibre plugins and Kindle support
# KFX Output 272407
# KFX Input 291290
COPY --chown=$USERNAME:$USERNAME kp3.reg /home/$USERNAME/kp3.reg
RUN cd /home/$USERNAME/ && curl -fsSLO https://d2bzeorukaqrvt.cloudfront.net/KindlePreviewerInstaller.exe \
    && env XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-runtime} DISPLAY=:0 WINEARCH=win64 WINEDEBUG=-all wine KindlePreviewerInstaller.exe /S \
    && cat kp3.reg >> /home/$USERNAME/.wine/user.reg && rm KindlePreviewerInstaller.exe && rm kp3.reg \
    && curl -fsSLO https://plugins.calibre-ebook.com/272407.zip \
    && calibre-customize -a 272407.zip \
    && curl -fsSLO https://plugins.calibre-ebook.com/291290.zip \
    && calibre-customize -a 291290.zip \
    && rm 272407.zip 291290.zip

COPY entrypoint.sh /sbin/entrypoint.sh
ENTRYPOINT ["/sbin/entrypoint.sh"]

WORKDIR /app
