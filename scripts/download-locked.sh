#!/usr/bin/env bash
set -euo pipefail

url=${1:?}
checksum=${2:?}
destination=${3:?}
algorithm=${checksum%%:*}
case "$algorithm" in
    sha256|md5) ;;
    *) printf 'Unsupported checksum: %s\n' "$algorithm" >&2; exit 1 ;;
esac

curl -fsSL --output "$destination" --url "$url"
printf '%s  %s\n' "${checksum#*:}" "$destination" | "${algorithm}sum" -c -
