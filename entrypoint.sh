#!/bin/bash
set -e

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

# Convert input file to output file
function convert_file {
    shift 2
    if [[ "$output_extension" == "kfx" ]]; then
        DISPLAY=:0 WINEARCH=win64 calibre-debug -r "KFX Output" -- "$input_file" "$@"
    else
        ebook-convert "$input_file" "$output_file" "$@"
    fi
}

convert_file "$input_file" "$output_file" "${@:3}"