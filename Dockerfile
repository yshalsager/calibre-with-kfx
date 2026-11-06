FROM public.ecr.aws/docker/library/debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS base

LABEL name="calibre-with-kfx" maintainer="yshalsager <contact@yshalsager.com>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates libx11-6 libxext6 libxrender1 libxi6 libxcursor1 libxinerama1 libxfixes3 \
        libxdamage1 libxrandr2 libxtst6 libxkbcommon-x11-0 libxcomposite1 libxcb-cursor0 \
        libfontconfig1 libnss3 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

ARG USERNAME=calibre
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" \
    && install -d -o "$USER_UID" -g "$USER_GID" /app \
    && install -d -m 700 -o "$USER_UID" -g "$USER_GID" /run/user/1000

ENV XDG_RUNTIME_DIR=/run/user/1000
COPY entrypoint.sh /sbin/entrypoint.sh
ENTRYPOINT ["/sbin/entrypoint.sh"]
WORKDIR /app

FROM base AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl xz-utils 7zip patch libegl1 libglx0 libopengl0 \
    && dpkg-query -W libegl1 libglx0 libopengl0 libglvnd0 > /tmp/libglvnd-packages.txt \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=755 scripts/download-locked.sh /usr/local/bin/download-locked

ARG CALIBRE_VERSION
ARG CALIBRE_URL
ARG CALIBRE_CHECKSUM
RUN download-locked "$CALIBRE_URL" "$CALIBRE_CHECKSUM" /tmp/calibre.txz \
    && mkdir -p /opt/calibre \
    && tar -xJf /tmp/calibre.txz -C /opt/calibre \
    && /opt/calibre/calibre_postinstall \
    && ebook-convert --version | grep -Fx "ebook-convert (calibre $CALIBRE_VERSION)" \
    && rm /tmp/calibre.txz

# shortcut: pin KFX Output 2.22.0 until upstream ships Linux KP4 support.
ARG KFX_OUTPUT_VERSION
ARG KFX_OUTPUT_URL
ARG KFX_OUTPUT_CHECKSUM
ARG KFX_INPUT_VERSION
ARG KFX_INPUT_URL
ARG KFX_INPUT_CHECKSUM
COPY --chown=$USERNAME:$USERNAME patches/kfx-output-linux-kp4.patch /tmp/kfx-output-linux-kp4.patch
USER calibre
RUN cd /home/"$USERNAME" \
    && download-locked "$KFX_OUTPUT_URL" "$KFX_OUTPUT_CHECKSUM" 272407.zip \
    && 7z x -y -okfx-output 272407.zip \
    && sed -i 's/\r$//' kfx-output/kfxlib/generate_kpf_{common,using_cli}.py \
    && patch --directory=kfx-output --strip=1 --batch --fuzz=0 < /tmp/kfx-output-linux-kp4.patch \
    && calibre-debug -c "import shutil; shutil.make_archive('kfx-output-patched', 'zip', 'kfx-output')" \
    && calibre-customize -a kfx-output-patched.zip \
    && download-locked "$KFX_INPUT_URL" "$KFX_INPUT_CHECKSUM" 291290.zip \
    && calibre-customize -a 291290.zip \
    && calibre-debug -c 'import sys; from calibre.customize.ui import find_plugin; actual = [".".join(map(str, find_plugin(name).version)) for name in ("KFX Input", "KFX Output")]; sys.exit(0 if actual == sys.argv[1:] else f"Plugin version mismatch: {actual} != {sys.argv[1:]}")' "$KFX_INPUT_VERSION" "$KFX_OUTPUT_VERSION" \
    && rm 272407.zip 291290.zip kfx-output-patched.zip /tmp/kfx-output-linux-kp4.patch \
    && rm -rf kfx-output

ARG KFXGEN_VERSION
ARG KFXGEN_URL
ARG KFXGEN_CHECKSUM
RUN download-locked "$KFXGEN_URL" "$KFXGEN_CHECKSUM" /tmp/kfxgen-source.zip \
    && 7z x -y -o/tmp /tmp/kfxgen-source.zip \
    && mv "/tmp/kfxgen-${KFXGEN_VERSION##*+}" /tmp/kfxgen \
    && cp /tmp/kfxgen/{LICENSE,NOTICE} /tmp/kfxgen/plugin/ \
    && printf 'kfxgen\nVersion: %s\nLicense: GPL v3\n' "$KFXGEN_VERSION" > /tmp/kfxgen/plugin/about.txt \
    && calibre-debug -c "import shutil; shutil.make_archive('/tmp/kfxgen', 'zip', '/tmp/kfxgen/plugin')" \
    && calibre-customize -a /tmp/kfxgen.zip \
    && calibre-customize --disable-plugin 'KFX Output' \
    && calibre-debug -c 'import sys; from calibre.customize.ui import find_plugin, plugin_for_output_format; actual = ".".join(map(str, find_plugin("kfxgen").version)); sys.exit(0 if actual == sys.argv[1] and plugin_for_output_format("kfx").name == "kfxgen" else f"kfxgen installation or selection failed: {actual}")' "${KFXGEN_VERSION%%+*}" \
    && rm -rf /tmp/kfxgen /tmp/kfxgen-source.zip /tmp/kfxgen.zip

USER root
ARG BOKO_VERSION
ARG BOKO_URL
ARG BOKO_CHECKSUM
RUN download-locked "$BOKO_URL" "$BOKO_CHECKSUM" /tmp/boko.tar.xz \
    && mkdir -p /opt/boko \
    && tar -xJf /tmp/boko.tar.xz -C /opt/boko --strip-components=1 \
    && /opt/boko/boko --version | grep -Fx "boko $BOKO_VERSION" \
    && printf 'Corresponding source: %s/source.tar.gz\n' "${BOKO_URL%/*}" > /opt/boko/SOURCE \
    && rm /tmp/boko.tar.xz

FROM build AS slim-build
USER root
RUN rm -rf /opt/calibre/share/espeak-ng-data /opt/calibre/lib/libonnxruntime.so.1 /opt/calibre/lib/libespeak-ng.so.1 \
    && find /opt/calibre/translations/qtwebengine_locales -type f ! -name en-US.pak ! -name ar.pak -delete

FROM build AS full-build
USER root
ARG WINE_URL
ARG WINE_CHECKSUM
RUN download-locked "$WINE_URL" "$WINE_CHECKSUM" /tmp/winehq-staging.deb \
    && curl -fsSLo /tmp/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && curl -fsSLo /tmp/winehq-trixie.sources https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources

ARG KP4_VERSION
ARG KP4_URL
ARG KP4_CHECKSUM
RUN download-locked "$KP4_URL" "$KP4_CHECKSUM" /tmp/KindlePreviewerSetup.exe \
    && 7z x -y -o/tmp/kp4-installer /tmp/KindlePreviewerSetup.exe '$PLUGINSDIR/KindlePreviewerApp.msix' \
    && 7z x -y -o/opt/kp4 '/tmp/kp4-installer/$PLUGINSDIR/KindlePreviewerApp.msix' \
    && test -f /opt/kp4/KindlePreviewerApp/KindlePreviewerCLI.exe \
    && calibre-debug -c 'import sys, xml.etree.ElementTree as ET; actual = ET.parse("/opt/kp4/AppxManifest.xml").find("{*}Identity").get("Version"); sys.exit(0 if actual == sys.argv[1] + ".0" else f"KP4 version mismatch: {actual} != {sys.argv[1]}.0")' "${KP4_VERSION%%+*}" \
    && rm -rf /tmp/KindlePreviewerSetup.exe /tmp/kp4-installer

FROM base AS slim
LABEL org.opencontainers.image.description="Native Calibre/KFX conversion without Wine or Kindle Previewer" \
    org.opencontainers.image.variant="slim"
COPY --from=slim-build /opt/calibre /opt/calibre
COPY --from=build /opt/boko/boko /usr/local/bin/boko
COPY --from=build /opt/boko/LICENSE /opt/boko/SOURCE /usr/local/share/doc/boko/
COPY --from=build --chown=$USERNAME:$USERNAME /home/$USERNAME/.config/calibre /home/$USERNAME/.config/calibre
# Qt needs GLVND loaders even headlessly, but not the Mesa/LLVM drivers.
COPY --from=build /usr/lib/x86_64-linux-gnu/libEGL.so.1* /usr/lib/x86_64-linux-gnu/libGLX.so.0* /usr/lib/x86_64-linux-gnu/libOpenGL.so.0* /usr/lib/x86_64-linux-gnu/libGLdispatch.so.0* /usr/local/lib/
COPY --from=build /usr/share/doc/libegl1/copyright /tmp/libglvnd-packages.txt /usr/local/share/doc/libglvnd/
RUN ldconfig && /opt/calibre/calibre_postinstall \
    && calibre-debug -c 'from qt.core import QColor, QImage'
ENV KFX_BACKEND=kfxgen
USER calibre

FROM base AS full
LABEL org.opencontainers.image.description="Calibre/KFX conversion with Kindle Previewer under Wine" \
    org.opencontainers.image.variant="full"
ARG WINE_VERSION
COPY --from=full-build /tmp/winehq-archive.key /etc/apt/keyrings/winehq-archive.key
COPY --from=full-build /tmp/winehq-trixie.sources /etc/apt/sources.list.d/winehq-trixie.sources
COPY --from=full-build /tmp/winehq-staging.deb /tmp/winehq-staging.deb
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends winbind /tmp/winehq-staging.deb xvfb xauth libegl1 libglx0 libopengl0 \
    && test "$(dpkg-query -W -f='${Version}' winehq-staging)" = "$WINE_VERSION" \
    && install -d -m 1777 /tmp/.X11-unix \
    && rm /tmp/winehq-staging.deb \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/calibre /opt/calibre
COPY --from=build /opt/boko/boko /usr/local/bin/boko
COPY --from=build /opt/boko/LICENSE /opt/boko/SOURCE /usr/local/share/doc/boko/
COPY --from=build --chown=$USERNAME:$USERNAME /home/$USERNAME/.config/calibre /home/$USERNAME/.config/calibre
COPY --from=full-build /opt/kp4 /opt/kp4
RUN /opt/calibre/calibre_postinstall
ENV KP4_PATH=/opt/kp4/KindlePreviewerApp KFX_BACKEND=previewer
USER calibre
RUN wine --version | grep -Fx "wine-${WINE_VERSION%%~*} (Staging)" \
    && WINEARCH=win64 WINEDEBUG=-all WINEDLLOVERRIDES=mscoree,mshtml= wineboot --init \
    && wineserver -w \
    && WINEDEBUG=-all wine "$KP4_PATH/KindlePreviewerCLI.exe" --help | grep -F 'Kindle Previewer 4.'
