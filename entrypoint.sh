#!/bin/bash
set -e

# Ensure a runtime dir exists for Xvfb/xauth when running headless
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR

# Print help message
function print_usage {
    echo "Usage: $0 [INPUT_FILE] [OUTPUT_FILE] [OPTIONS]"
    echo "Converts an ebook to a different format using Calibre's ebook-convert."
}

while getopts ":h" opt; do
    case ${opt} in
        h)
            print_usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" 1>&2
            print_usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

input_file="$1"
output_file="$2"

# Validate input and output files
if [[ -z "$input_file" || -z "$output_file" ]]; then
    echo "Input and output files are required."
    print_usage
    exit 1
fi

if [[ ! -f "$input_file" ]]; then
    echo "Input file not found: $input_file"
    exit 1
fi

# Determine output file extension
output_extension="${output_file##*.}"

function run_with_xvfb {
    local display=":${XVFB_DISPLAY:-99}"
    local screen="${XVFB_SCREEN:-1280x720x24}"
    Xvfb "$display" -screen 0 "$screen" -nolisten tcp -ac &
    local xvfb_pid=$!
    trap "kill -TERM ${xvfb_pid} 2>/dev/null || true" EXIT
    # Give Xvfb a moment to initialize
    sleep 2
    export DISPLAY="$display"
    "$@"
    local status=$?
    kill -TERM $xvfb_pid 2>/dev/null || true
    wait $xvfb_pid 2>/dev/null || true
    trap - EXIT
    return $status
}

# Convert input file to output file
function convert_file {
    shift 2
    if [[ "$output_extension" == "kfx" ]]; then
        # KFX Output's CLI accepts: infile [outfile] plus flags like --pages/--book/etc.
        run_with_xvfb calibre-debug -r "KFX Output" -- "$input_file" "$output_file" "$@"
    else
        ebook-convert "$input_file" "$output_file" "$@"
    fi
}

convert_file "$input_file" "$output_file" "${@:3}"
