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

[Calibre](https://calibre-ebook.com/)'s [KFX Output](https://www.mobileread.com/forums/showthread.php?t=272407) plugin requires Amazon's [Kindle Previewer 4](https://kdp.amazon.com/en_US/help/topic/G202131170), which isn't available on Linux. This image runs it using [Wine](https://appdb.winehq.org/objectManager.php?sClass=application&iId=18012).

It also includes [kfxgen](https://github.com/jloutsch/kfxgen) for native KFX generation without Previewer or Wine, and [KFX Input](https://www.mobileread.com/forums/showthread.php?t=291290) for converting KFX to other formats.

## Usage

You can [build the locked image locally](#building-and-testing), or pull it from [Docker Hub](https://hub.docker.com/r/yshalsager/calibre-with-kfx):

```bash
docker pull yshalsager/calibre-with-kfx
```

### Image variants

| Tags | Default KFX backend | Contents |
| --- | --- | --- |
| `latest`, `full`, `<version>` | `previewer` | Complete Calibre payload, all three KFX plugins, Wine and KP4 |
| `slim`, `<version>-slim` | `kfxgen` | Headless Calibre and all three KFX plugins, without Wine/KP4 or speech synthesis |

The slim image retains PDF conversion, fonts, Unicode support, dictionaries and hyphenation. It uses only the GLVND loader libraries needed by headless Qt, not the Mesa/LLVM driver stack. It keeps English and Arabic Chromium UI locales; this does not restrict book languages. It is not a desktop/GPU image and cannot use the Previewer backend.

**Downstream applications must provide their own standalone Python.** Both variants retain Calibre's embedded Python, but no longer provide an application interpreter as part of their base-image contract. For `ebook-converter-bot`, copy a pinned official Python runtime from the same Debian trixie release before running its frozen uv sync. The bot also selects its own backends: changing the base image's `KFX_BACKEND` does not disable its Previewer routes.

Once you have the Docker image, you can run it using the following command:

```bash
docker run --rm -it -v "/path/to/local/folder:/app:rw" yshalsager/calibre-with-kfx [input_file] [output_file] [extra args]
```

### Examples:

- Convert to azw3 with extra arguments: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx epub30-spec.epub epub30-spec.azw3 --dont-compress`
- Convert to KFX: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx epub30-spec.epub epub30-spec.kfx`
- Convert to KFX with approximate page numbers (auto): `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx book.epub book.kfx --pages 0`
- Convert natively with the slim image: `docker run --rm -it -v "$(pwd):/app:rw" yshalsager/calibre-with-kfx:slim book.epub book.kfx --kfxgen-open-at-cover`

### KFX backends

`KFX_BACKEND` selects the backend when the output is KFX:

- `previewer` (full image default): KFX Output via Kindle Previewer under Wine; preserves existing conversion behavior.
- `kfxgen` (slim image default): native generation via `ebook-convert`, without starting Wine or Xvfb. Also available in the full image.

```bash
docker run --rm -it -v "$(pwd):/app:rw" -e KFX_BACKEND=kfxgen yshalsager/calibre-with-kfx \
  book.epub book.kfx --kfxgen-open-at-cover
```

Options are backend-specific and are passed through unchanged. There is no automatic fallback between backends. Non-KFX output ignores `KFX_BACKEND`.

For `previewer`, extra args are passed to KFX Output (`calibre-debug -r "KFX Output" -- ...`). Useful flags include:

- `--pages N` create approximate page numbers if missing (`0` = auto)
- `--book` mark as EBOK (vs default PDOC)
- `--asin BXXXXXXXXX` set an ASIN
- `--logs` include Kindle Previewer conversion logs
- `--quality` include Kindle Previewer quality report
- `--timeout` stop conversions lasting over ~15 minutes

For `kfxgen`, extra args are `ebook-convert` options, including:

- `--kfxgen-open-at-cover` open new books at their cover
- `--kfxgen-disable-approximate-pages` skip estimated page numbers (enabled by default when real pages are missing)
- `--kfxgen-disable-font-embedding` use the Kindle's selected font instead of embedding publisher fonts
- `--kfxgen-embed-original-images` preserve original image resolution
- `--kfxgen-disable-native-tables` write tables as paragraphs

kfxgen does not accept Previewer's `--pages`, `--book`, or `--asin` flags. This image builds it from pinned commit [`c50f414`](https://github.com/jloutsch/kfxgen/commit/c50f414197a4a236ebe4a654a3b2b3b7067a25ee), including RTL fixes not yet released in 5.23.0. Its output can still differ in formatting, so Previewer remains the full image's default.

Both plugins stay installed in both variants. KFX Output is disabled for automatic format selection, so direct `ebook-convert book.epub book.kfx` uses kfxgen. In the full image, its explicit `calibre-debug -r "KFX Output" -- ...` command still uses Previewer. Keeping the plugin in slim does not provide a Previewer runtime.

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
mise run versions       # inspect the committed full-image versions, without network discovery
mise run build          # build target full as calibre-with-kfx:local
mise run test           # full-image conversions; prints a fresh temporary output directory
VARIANT=slim mise run versions
VARIANT=slim mise run build  # build target slim as calibre-with-kfx:slim-local
VARIANT=slim mise run test   # native conversions, RTL/PDF checks, and absence of Wine/standalone Python
mise run test-tracking      # offline metadata, variant, and checksum regression tests
```

Use `calibre-with-kfx:local` or `calibre-with-kfx:slim-local` in the usage examples to run a local image. `mise run build` supplies the required locked build arguments; a bare Docker build still needs them. The last/default Dockerfile target is `full`.

To test another full image, run `IMAGE=ghcr.io/yshalsager/calibre-with-kfx:<tag> mise run test`. For slim, use `VARIANT=slim IMAGE=ghcr.io/yshalsager/calibre-with-kfx:<tag>-slim mise run test`. The manual conversion-test workflow also requires the matching variant; checks are explicit rather than silently skipping a missing full-image runtime.

Calibre and plugin artifacts are prepared in shared builder stages. Slim never needs the Wine/KP4 build stages. Speech data and unused Chromium locales are removed before the slim payload is copied into its final stage, rather than deleted from a retained parent layer. Download/extraction tools and standalone Python are not needed in the conversion runtime.

## Versioning

`mise.tracking.lock` records the versions, artifact URLs, and checksums used by Docker. Labels and [GitHub releases](https://github.com/yshalsager/calibre-with-kfx/releases) read the same lockfile, omitting Wine/KP4 for slim. Calibre versions are discovered through GitHub, but Linux artifacts come from the official versioned archive because GitHub removes older binaries. The Debian base image remains pinned in `Dockerfile` and updated by Renovate.

Version discovery is isolated in `mise.tracking.toml`, so normal mise commands do not fetch upstream metadata. To update:

```sh
mise trust mise.tracking.toml
mise run update-versions
git diff -- mise.tracking.lock
```

The weekly version workflow commits lockfile changes, triggering builds and conversion tests for both variants. The publish workflow also runs weekly to refresh signed apt dependencies, including copied graphics libraries, when tool versions have not changed. Publication is serialized; both images must pass before either is published, and the tested images are pushed without rebuilding.

A release uses a UTC `YYYYMMDD-HHMMSS` tag for full and `<version>-slim` for slim. Only a build of the current `master` head updates the moving `latest`, `full`, and `slim` aliases; older reruns can publish dated tags without rolling those aliases backward.

Slim's manually copied GLVND libraries come from the same Debian builder. Their license and installed package versions are recorded under `/usr/local/share/doc/libglvnd/`; include these files in security inventory rather than relying only on the runtime apt database. Other OS dependencies are also not individually locked.

KP4 is tracked as `version+etag`: Amazon's release notes supply the advertised version, and a HEAD request detects Windows installer replacements. Amazon currently publishes only an MD5 for that installer; it is a content-change check, not strong authenticity verification. The build checks the extracted Windows package version against the advertised version and fails on a mismatch. Mutable vendor URLs can stop serving older locked artifacts.

kfxgen is temporarily pinned as `version+commit` to include unreleased RTL fixes. Its source archive is checksum-verified, then packaged as a Calibre plugin during the build, including upstream license notices. Return to release tracking once those fixes ship.

KFX Output stays pinned at 2.22.0 while `patches/kfx-output-linux-kp4.patch` provides Linux KP4 support. Review the patch and conversion tests before changing that pin. Wine tracking pins the staging metapackage for Debian trixie, whose exact-version dependencies pin the amd64/i386 Wine packages. Apt verifies those dependencies against its signed repository metadata; their hashes and other OS dependencies are not individually recorded in the mise lockfile.
