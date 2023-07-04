# Calibre with KFX Docker

![GitHub CI](https://github.com/yshalsager/calibre-with-kfx/actions/workflows/publish.yml/badge.svg)
[![Docker Hub badge](https://img.shields.io/docker/pulls/yshalsager/calibre-with-kfx)](https://hub.docker.com/r/yshalsager/calibre-with-kfx)

[![GitHub license](https://img.shields.io/github/license/yshalsager/calibre-with-kfx.svg)](https://github.com/yshalsager/calibre-with-kfx/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/yshalsager/calibre-with-kfx.svg)](https://GitHub.com/yshalsager/calibre-with-kfx/releases/)


A Docker image for converting eBooks using Calibre with KFX support.

> KFX is Amazon's proprietary eBook format used for Kindle devices.

## Why?

Because Amazon's Kindle Previewer is the only way currently to convert books into KFX, and it's not available on Linux, so I run it under docker using wine.

## Usage
To use the Docker image, you can build it locally using the Dockerfile provided in this repository, or you can pull the image from [Docker Hub](https://hub.docker.com/r/yshalsager/calibre-with-kfx) using the following command:

```bash
docker pull yshalsager/calibre-with-kfx
```

Once you have the Docker image, you can run it using the following command:

```bash
docker run -it --rm -v /path/to/local/folder:/data yshalsager/calibre-with-kfx [input_file] [output_file] [extra args]
```

### Examples:

- Convert to azw3 with extra arguments: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx -i epub30-spec.epub -o epub30-spec.azw3 --dont-compress`
- Convert to KFX: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx -i epub30-spec.epub -o epub30-spec.kfx`

## Versioning

The docker image versions are tagged with build date and time. There's a [GitHub release](https://github.com/yshalsager/calibre-with-kfx/releases) for each tag that lists versions of each component of the image, like base OS, Calibre and its plugins, and Kindle Previewer.

Whenever any component gets updated, a new image is built and pushed.
