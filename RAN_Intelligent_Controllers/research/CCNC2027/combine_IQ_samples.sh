#!/bin/bash

for dir in AWGN*/; do
    # Remove trailing slash and replace '+' with '_'
    dir_name="${dir%/}"
    safe_name="${dir_name//+/_}"

    output="COMBINED_${safe_name}.csv"

    echo "Combining $dir_name -> $output"

    # Write header once
    echo "real;imag" >"$output"

    # Append all IQ rows, skipping each file's header
    for file in "$dir"iq_*.csv; do
        tail -n +2 "$file" >>"$output"
    done
done
