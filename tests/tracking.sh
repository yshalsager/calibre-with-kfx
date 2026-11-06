#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
mkdir -p "$work/project" "$work/bin" "$work/config"

printf 'locked artifact\n' > "$work/source"
for algorithm in sha256 md5; do
    digest=$("${algorithm}sum" "$work/source" | cut -d ' ' -f 1)
    bash "$root/scripts/download-locked.sh" "file://$work/source" "$algorithm:$digest" "$work/download with spaces"
    cmp "$work/source" "$work/download with spaces"
done
if bash "$root/scripts/download-locked.sh" "file://$work/source" "sha256:$(printf '%064d' 0)" "$work/corrupt" >/dev/null 2>&1; then
    echo 'A mismatched checksum was accepted' >&2
    exit 1
fi
if bash "$root/scripts/download-locked.sh" "file://$work/source" 'unsupported:hash' "$work/unsupported" >/dev/null 2>&1; then
    echo 'An unsupported checksum was accepted' >&2
    exit 1
fi
test ! -e "$work/unsupported"

cp "$root/mise.toml" "$root/mise.tracking.toml" "$work/project/"
printf 'FROM example.invalid/debian:trixie-slim@sha256:base AS base\n' > "$work/project/Dockerfile"
printf 'lockfile_version = 3\n' > "$work/project/mise.tracking.lock"
printf 'base: example.invalid/debian:trixie-slim@sha256:base\n' > "$work/expected-versions"
while IFS='|' read -r name version; do
    prefix=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
    checksum="sha256:$(printf '%064d' 0)"
    if [[ "$name" == kp4 ]]; then checksum="md5:$(printf '%032d' 0)"; fi
    printf '\n[[tools.%s]]\nversion = "%s"\n' "$name" "$version" >> "$work/project/mise.tracking.lock"
    printf '\n[tools.%s."platforms.linux-x64"]\nurl = "https://example.invalid/%s"\nchecksum = "%s"\n' \
        "$name" "$prefix" "$checksum" >> "$work/project/mise.tracking.lock"
    printf '%s_VERSION=%s\n%s_URL=https://example.invalid/%s\n%s_CHECKSUM=%s\n' \
        "$prefix" "$version" "$prefix" "$prefix" "$prefix" "$checksum" >> "$work/expected-args"
    printf '%s: %s\n' "$name" "$version" >> "$work/expected-versions"
done <<'FIXTURES'
boko|0.6.0
calibre|9.1.2
kfx_input|2.3.4
kfx_output|2.22.0
kfxgen|5.23.0+c50f414197a4a236ebe4a654a3b2b3b7067a25ee
kp4|4.0.4+aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
wine|11.1~trixie-1
FIXTURES

cat > "$work/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" != -fsSI ]]; then exit 0; fi
printf 'HEAD\n' >> "$HEAD_LOG"
if [[ "${TEST_HEAD:-}" == fail ]]; then exit 22; fi
printf 'HTTP/2 200\r\netag: "%s"\r\n' "$TEST_ETAG"
if [[ "${TEST_HEAD:-}" != missing ]]; then
    printf 'x-amz-meta-md5-hash: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\r\n'
fi
printf '\r\n'
CURL
cat > "$work/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DOCKER_LOG"
DOCKER
chmod +x "$work/bin/curl" "$work/bin/docker"
export PATH="$work/bin:$PATH"
export MISE_CONFIG_DIR="$work/config"
export MISE_CACHE_DIR="$work/cache"
export MISE_TRUSTED_CONFIG_PATHS="$work/project"
export HEAD_LOG="$work/heads" DOCKER_LOG="$work/docker"
export TEST_ETAG=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export HTTP_PROXY=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9
unset MISE_ENV VARIANT
cd "$work/project"
mise run --quiet --output=interleave versions > "$work/versions"
diff -u "$work/expected-versions" "$work/versions"
mise run --quiet --output=interleave versions > "$work/versions-again"
cmp "$work/versions" "$work/versions-again"
mise run --quiet --output=interleave build
[[ $(grep -c '^--build-arg$' "$DOCKER_LOG") == 21 ]]
while IFS= read -r argument; do grep -Fxq -- "$argument" "$DOCKER_LOG"; done < "$work/expected-args"
grep -Fxq 'linux/amd64' "$DOCKER_LOG"
grep -Fxq 'full' "$DOCKER_LOG"
grep -Fxq 'calibre-with-kfx:local' "$DOCKER_LOG"
IMAGE=example.invalid/published:manual mise run --quiet --output=interleave test > "$work/test.log"
grep -Fxq 'example.invalid/published:manual' "$DOCKER_LOG"
grep -Fxq 'full' "$DOCKER_LOG"

VARIANT=slim mise run --quiet --output=interleave versions > "$work/slim-versions"
grep -Ev '^(kp4|wine): ' "$work/expected-versions" > "$work/expected-slim-versions"
diff -u "$work/expected-slim-versions" "$work/slim-versions"
VARIANT=slim mise run --quiet --output=interleave build
[[ $(grep -c '^--build-arg$' "$DOCKER_LOG") == 15 ]]
while IFS= read -r argument; do
    case "$argument" in KP4_*|WINE_*) continue ;; esac
    grep -Fxq -- "$argument" "$DOCKER_LOG"
done < "$work/expected-args"
if grep -Eq '^(KP4|WINE)_' "$DOCKER_LOG"; then
    echo 'The slim build received Previewer or Wine arguments' >&2
    exit 1
fi
grep -Fxq 'slim' "$DOCKER_LOG"
grep -Fxq 'calibre-with-kfx:slim-local' "$DOCKER_LOG"
VARIANT=slim mise run --quiet --output=interleave test > "$work/slim-test.log"
grep -Fxq 'calibre-with-kfx:slim-local' "$DOCKER_LOG"
grep -Fxq 'slim' "$DOCKER_LOG"
before=$(sha256sum "$DOCKER_LOG")
for task in versions build test; do
    if VARIANT=invalid mise run --quiet --output=interleave "$task" >/dev/null 2>&1; then
        echo "An invalid variant was accepted by $task" >&2
        exit 1
    fi
done
[[ "$before" == "$(sha256sum "$DOCKER_LOG")" ]]
test ! -e "$HEAD_LOG"

perl -MIO::Socket::INET -e '
    $| = 1;
    my $server = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => 0, Listen => 4) or die $!;
    print $server->sockport, "\n";
    while (my $client = $server->accept) {
        while (<$client>) { last if /^\r?$/; }
        my $body = "New in Kindle Previewer 4.0.4:\n";
        print {$client} "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: ", length($body), "\r\n\r\n", $body;
        close $client;
    }
' > "$work/port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
for _ in {1..100}; do test -s "$work/port" && break; sleep 0.1; done
read -r port < "$work/port"
awk '/^\[tools\./ { tool_section=1; kp4=($0 == "[tools.kp4]") } !tool_section || kp4' "$root/mise.tracking.toml" |
    sed -e "s|https://kindlepreviewer.s3.amazonaws.com/UG_ReleaseNotes_EN.txt|http://127.0.0.1:$port/notes|" \
        -e 's|https://d3mb67z9ki82yk.cloudfront.net/KindlePreviewerSetup.exe|https://installer-download-disabled.invalid/installer.exe|g' \
        > mise.tracking.toml
mv mise.tracking.lock "$work/render-only.lock"
export NO_PROXY=127.0.0.1,localhost
for TEST_ETAG in cccccccccccccccccccccccccccccccc aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; do
    export TEST_ETAG
    mise -E tracking lock --bump --platform linux-x64 kp4 > "$work/repack.log" 2>&1
    grep -Fxq "version = \"4.0.4+$TEST_ETAG\"" mise.tracking.lock
    grep -Fxq 'checksum = "md5:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"' mise.tracking.lock
done
before=$(sha256sum mise.tracking.lock)
mise -E tracking lock --bump --platform linux-x64 kp4 > "$work/repack.log" 2>&1
[[ "$before" == "$(sha256sum mise.tracking.lock)" ]]
for TEST_HEAD in missing fail; do
    export TEST_HEAD
    if mise -E tracking lock --bump --platform linux-x64 kp4 > "$work/repack.log" 2>&1; then
        echo "Invalid HEAD response was accepted: $TEST_HEAD" >&2
        exit 1
    fi
    [[ "$before" == "$(sha256sum mise.tracking.lock)" ]]
done
mv "$DOCKER_LOG" "$work/docker-before-missing-lock"
mv mise.tracking.lock "$work/missing.lock"
if mise run --quiet --output=interleave build >/dev/null 2>&1; then
    echo 'A build without a lockfile was accepted' >&2
    exit 1
fi
test ! -e "$DOCKER_LOG"
printf 'Tracking checks passed (fixtures: %s)\n' "$work"
