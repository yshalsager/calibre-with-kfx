#!/bin/bash

# Print help message
function print_usage {
    echo "Usage: $0 [-i INPUT_FILE] [-o OUTPUT_FILE]"
    echo "Converts an ebook to a different format using Calibre's ebook-convert."
}

# Parse input arguments
while getopts ":i:o:h" opt; do
  case $opt in
    i)
      input_file=$OPTARG
      ;;
    o)
      output_file=$OPTARG
      ;;
    h)
      print_usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      print_usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      print_usage
      exit 1
      ;;
  esac
done

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
if [[ "$output_extension" == "kfx" ]]; then
    calibre-debug -r "KFX Output" -- "$input_file" "${@:3}"
else
    ebook-convert "$input_file" "$output_file" "${@:3}"
fi