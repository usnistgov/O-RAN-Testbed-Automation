#!/bin/bash
echo "# Script: $(realpath $0)..."

# Get the file path from the command line argument
FILE=$1

# Check if the file path is provided
if [[ -z "$FILE" ]]; then
    echo "Error: No file path provided."
    echo "Usage: $0 <path_to_yaml_file>"
    exit 1
fi

# Check if the file exists and is readable
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' does not exist."
    exit 1
fi

if [[ ! -r "$FILE" ]]; then
    echo "Error: File '$FILE' is not readable."
    exit 1
fi

echo "Revising $1..."

# Search for the line containing the commented CMD and modify it if found
if grep -q "#CMD sleep 100000000000" "$FILE"; then
    # The line is found; replace the line by removing the comment
    sed -i '/#CMD sleep 100000000000/c\CMD sleep 100000000000' "$FILE"
    echo "Replaced the commented command."
else
    # The line is not found; append the new command at the end of the file
    echo -e "\nCMD sleep 100000000000" >> "$FILE"
    echo "Appended the new command at the end of the file."
fi

echo "Revision completed."

