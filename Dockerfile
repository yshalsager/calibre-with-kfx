# Use python:3.11-slim-bullseye as base image to have a smaller image and avoid installing python manually
FROM python:3.11-slim-bullseye

# Configure Paths
RUN export PATH=$PATH

# Install prerequisites
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
                  ca-certificates \
                  xvfb \
                  libegl1 \
                  libopengl0 \
                  libxkbcommon-x11-0 \
                  libxcomposite-dev \
                  # QTWebEngine deps
                  libxdamage-dev libxrandr-dev libxtst6 \
                  curl \
                  gnupg2 \
                  xz-utils \
                  && rm -rf /var/lib/apt/lists/*

# Install wine
ARG WINE_BRANCH="stable"
RUN dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && curl -o /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && curl -L -o /etc/apt/sources.list.d/winehq-bullseye.sources https://dl.winehq.org/wine-builds/debian/dists/bullseye/winehq-bullseye.sources \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends winbind winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# Kindle support
COPY kp3.reg .
RUN curl -s -O https://d2bzeorukaqrvt.cloudfront.net/KindlePreviewerInstaller.exe \
    && DISPLAY=:0 WINEARCH=win64 WINEDEBUG=-all wine KindlePreviewerInstaller.exe /S \
    && cat kp3.reg >> /root/.wine/user.reg && rm *.exe

# calibre and its plugins are
# KFX Output 272407
# KFX Input 291290
RUN curl -s https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin \
    && curl -s -O https://plugins.calibre-ebook.com/272407.zip \
    && calibre-customize -a 272407.zip \
    && curl -s -O https://plugins.calibre-ebook.com/291290.zip \
    && calibre-customize -a 291290.zip \
    && rm *.zip
