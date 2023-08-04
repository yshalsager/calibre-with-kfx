# Calibre with KFX Docker

![GitHub CI](https://github.com/yshalsager/calibre-with-kfx/actions/workflows/publish.yml/badge.svg)
[![Docker Hub badge](https://img.shields.io/docker/pulls/yshalsager/calibre-with-kfx)](https://hub.docker.com/r/yshalsager/calibre-with-kfx)
[![ghcr.io badge](https://ghcr-badge.egpl.dev/yshalsager/calibre-with-kfx/latest_tag?trim=major&label=GitHub%20Registry&color=steelblue)](https://github.com/yshalsager/calibre-with-kfx/pkgs/container/calibre-with-kfx)
[![ghcr.io size badge](https://ghcr-badge.egpl.dev/yshalsager/calibre-with-kfx/size?tag=latest&label=Image%20size&color=steelblue)](https://github.com/yshalsager/calibre-with-kfx/pkgs/container/calibre-with-kfx)

[![GitHub license](https://img.shields.io/github/license/yshalsager/calibre-with-kfx.svg)](https://github.com/yshalsager/calibre-with-kfx/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/yshalsager/calibre-with-kfx.svg)](https://GitHub.com/yshalsager/calibre-with-kfx/releases/latest)

[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?style=flat&labelColor=00457C&logo=PayPal&logoColor=white&link=https://www.paypal.me/yshalsager)](https://www.paypal.me/yshalsager)
[![Patreon](https://img.shields.io/badge/Patreon-Support-F96854?style=flat&labelColor=F96854&logo=Patreon&logoColor=white&link=https://www.patreon.com/XiaomiFirmwareUpdater)](https://www.patreon.com/XiaomiFirmwareUpdater)
[![Liberapay](https://img.shields.io/badge/Liberapay-Support-F6C915?style=flat&labelColor=F6C915&logo=Liberapay&logoColor=white&link=https://liberapay.com/yshalsager)](https://liberapay.com/yshalsager)

A Docker image for converting eBooks using Calibre with KFX support.

> KFX is Amazon's proprietary eBook format used for Kindle devices.

## Why?

Because Amazon's [Kindle Previewer 3](https://kdp.amazon.com/en_US/help/topic/G202131170) is the only way currently to convert books into KFX using [Calibre](https://calibre-ebook.com/) [KFX Input](https://www.mobileread.com/forums/showthread.php?t=291290)
and [KFX Output](https://www.mobileread.com/forums/showthread.php?t=272407) plugins, and it's not available on Linux, so I run it under docker using [Wine](https://appdb.winehq.org/objectManager.php?sClass=application&iId=18012).

## Usage

To use the Docker image, you can build it locally using the Dockerfile provided in this repository, or you can pull the image from [Docker Hub](https://hub.docker.com/r/yshalsager/calibre-with-kfx) using the following command:

```bash
docker pull yshalsager/calibre-with-kfx
```

Once you have the Docker image, you can run it using the following command:

```bash
docker run --rm -it -v "/path/to/local/folder:/app:rw" yshalsager/calibre-with-kfx [input_file] [output_file] [extra args]
```

### Examples:

- Convert to azw3 with extra arguments: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx epub30-spec.epub epub30-spec.azw3 --dont-compress`
- Convert to KFX: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx epub30-spec.epub epub30-spec.kfx`

## Versioning

The docker image versions are tagged with build date and time. There's a [GitHub release](https://github.com/yshalsager/calibre-with-kfx/releases) for each tag that lists versions of each component of the image, like base OS, Calibre and its plugins, and Kindle Previewer.

Whenever any component gets updated, a new image is built and pushed.
