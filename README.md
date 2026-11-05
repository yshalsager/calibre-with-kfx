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

Because Amazon's [Kindle Previewer 4](https://kdp.amazon.com/en_US/help/topic/G202131170) is the only way currently to convert books into KFX using [Calibre](https://calibre-ebook.com/) [KFX Input](https://www.mobileread.com/forums/showthread.php?t=291290)
and [KFX Output](https://www.mobileread.com/forums/showthread.php?t=272407) plugins, and it's not available on Linux, so I run it under docker using [Wine](https://appdb.winehq.org/objectManager.php?sClass=application&iId=18012).

## Usage

You can [build the locked image locally](#building-and-testing), or pull it from [Docker Hub](https://hub.docker.com/r/yshalsager/calibre-with-kfx):

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
- Convert to KFX with approximate page numbers (auto): `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx book.epub book.kfx --pages 0`

When converting to KFX, extra args are passed to the KFX Output plugin (`calibre-debug -r "KFX Output" -- ...`). Useful flags include:

- `--pages N` create approximate page numbers if missing (`0` = auto)
- `--book` mark as EBOK (vs default PDOC)
- `--asin BXXXXXXXXX` set an ASIN
- `--logs` include Kindle Previewer conversion logs
- `--quality` include Kindle Previewer quality report
- `--timeout` stop conversions lasting over ~15 minutes

When converting from KFX to other formats, this image uses `ebook-convert` normally. Any `ebook-convert` CLI options can be passed as extra args.

The KFX Input plugin also provides a separate CLI (useful for print replica PDF extraction, CBZ creation, resource unpacking, etc):

```bash
docker run --rm -it -v "$(pwd):/app:rw" --entrypoint calibre-debug yshalsager/calibre-with-kfx \
  -r "KFX Input" -- /app/book.kfx --help
```

Common KFX Input CLI flags:

- `--epub` (default), `--epub2`
- `--pdf` extract/produce PDF (print replica, comics/children's)
- `--cbz` create CBZ (print replica, comics/children's)
- `--unpack` extract resources to a ZIP
- `--json-content` create JSON content/position file
- `--cover` force a generic EPUB cover if missing

KFX Input has one calibre "Convert Books" option: `allow_conversion_with_errors` (default off). It also has plugin preferences used by its CLI/From-KFX UI (for example splitting landscape comic images when creating PDF).

## Building and testing

Requires Docker and [mise](https://mise.jdx.dev/) 2026.11.0 or newer. The offline tracking tests also use Perl's standard socket module and GNU checksum utilities. The image targets Linux amd64, including when built on another architecture.

```sh
mise trust mise.toml
mise run versions       # inspect the committed versions, without network discovery
mise run build          # build calibre-with-kfx:local from the lockfile
mise run test           # conversion tests; prints the temporary output directory
mise run test-tracking  # offline metadata and checksum regression tests
```

Use `calibre-with-kfx:local` in the usage examples to run your local image. `mise run build` supplies the required locked build arguments. To test another image, run `IMAGE=ghcr.io/yshalsager/calibre-with-kfx:<tag> mise run test`, or dispatch the conversion-test workflow manually.

## Versioning

`mise.tracking.lock` records the versions, artifact URLs, and checksums used by Docker. Labels and [GitHub releases](https://github.com/yshalsager/calibre-with-kfx/releases) read the same lockfile. The base image remains pinned in `Dockerfile` and updated by Renovate.

Version discovery is isolated in `mise.tracking.toml`, so normal mise commands do not fetch upstream metadata. To update:

```sh
mise trust mise.tracking.toml
mise run update-versions
git diff -- mise.tracking.lock
```

The weekly workflow commits lockfile changes, triggering a build, conversion tests, and publication with a UTC date/time plus unique workflow-run tag. Publication is serialized and pushes the tested image without rebuilding it or repeating conversions after publication. Only a build of the current `master` head updates `latest`; older reruns can publish their unique version tags without rolling `latest` backward.

KP4 is tracked as `version+etag`: Amazon's release notes supply the advertised version, and a HEAD request detects Windows installer replacements. Amazon currently publishes only an MD5 for that installer; it is a content-change check, not strong authenticity verification. The build checks the extracted Windows package version against the advertised version and fails on a mismatch. Mutable vendor URLs can stop serving older locked artifacts.

KFX Output stays pinned at 2.22.0 while `patches/kfx-output-linux-kp4.patch` provides Linux KP4 support. Review the patch and conversion tests before changing that pin. Wine tracking pins the staging metapackage for Debian trixie, whose exact-version dependencies pin the amd64/i386 Wine packages. Apt verifies those dependencies against its signed repository metadata; their hashes and other OS dependencies are not individually recorded in the mise lockfile.
