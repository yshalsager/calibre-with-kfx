FROM public.ecr.aws/docker/library/python:3.15-slim-trixie@sha256:533b0b2f9b5d46fd097091cf826f27902f1d6c3bca714b6dc74551356aa97a51

LABEL name="calibre-with-kfx" maintainer="yshalsager <contact@yshalsager.com>"
LABEL org.opencontainers.image.description="An image for running Calibre with KFX support to allow conversion of KFX files to other formats."

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Calibre deps
    ca-certificates curl gnupg2 xz-utils 7zip patch \
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

ENV KP4_PATH=/opt/kp4/KindlePreviewerApp

# Extract the CLI payload without Windows MSIX registration.
RUN curl -fsSLo /tmp/KindlePreviewerSetup.exe https://d3mb67z9ki82yk.cloudfront.net/KindlePreviewerSetup.exe \
    && 7z x -y -o/tmp/kp4-installer /tmp/KindlePreviewerSetup.exe '$PLUGINSDIR/KindlePreviewerApp.msix' \
    && 7z x -y -o/opt/kp4 '/tmp/kp4-installer/$PLUGINSDIR/KindlePreviewerApp.msix' \
    && test -f "$KP4_PATH/KindlePreviewerCLI.exe" \
    && rm -rf /tmp/KindlePreviewerSetup.exe /tmp/kp4-installer

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
RUN WINEARCH=win64 WINEDEBUG=-all WINEDLLOVERRIDES=mscoree,mshtml= wineboot --init \
    && wineserver -w \
    && WINEDEBUG=-all wine "$KP4_PATH/KindlePreviewerCLI.exe" --help | grep -F 'Kindle Previewer 4.'

# shortcut: pin KFX Output 2.22.0 until upstream ships Linux KP4 support.
COPY --chown=$USERNAME:$USERNAME patches/kfx-output-linux-kp4.patch /tmp/kfx-output-linux-kp4.patch
RUN cd /home/$USERNAME/ && curl -fsSLO https://plugins.calibre-ebook.com/272407.zip \
    && echo '8202c723487be06a9461c2eb1c91984076c71935766303e65ae48933c2efb802  272407.zip' | sha256sum -c - \
    && 7z x -y -okfx-output 272407.zip \
    && sed -i 's/\r$//' kfx-output/kfxlib/generate_kpf_{common,using_cli}.py \
    && patch --directory=kfx-output --strip=1 --batch --fuzz=0 < /tmp/kfx-output-linux-kp4.patch \
    && python -c "import shutil; shutil.make_archive('kfx-output-patched', 'zip', 'kfx-output')" \
    && calibre-customize -a kfx-output-patched.zip \
    && curl -fsSLO https://plugins.calibre-ebook.com/291290.zip \
    && calibre-customize -a 291290.zip \
    && rm 272407.zip 291290.zip kfx-output-patched.zip /tmp/kfx-output-linux-kp4.patch \
    && rm -rf kfx-output

COPY entrypoint.sh /sbin/entrypoint.sh
ENTRYPOINT ["/sbin/entrypoint.sh"]

WORKDIR /app
