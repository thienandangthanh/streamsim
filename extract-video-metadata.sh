#!/bin/bash

# Output CSV file
INPUT_DIR="$1"
OUTPUT_FILE="$2"
TMP_FILE=$(mktemp)

# Validate arguments
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 <input_directory> <output_csv_file>"
    exit 1
fi

# Write CSV header
cat << EOF > "$OUTPUT_FILE"
# SRC
# ===
#
# In this csv file you are able to specify which link resources should be used to perform operations on in the processing
# chain. Be aware that each file listed here must exists in the "srcVid" folder.
#
# Fields:
# -------
#
# * <type 'int'> src_id   : unique id to identify each individual source
#
# * <type 'str'> src_name : unique name to identify the source file in the folder "srcVid"
#
# * <type 'str'> res      : video frame resolution in px
#
# * <type 'int'> fps      : number of frames to encode the video with (unit: frame/s)
#
#
# Annotation:
# -----------
#
# The table columns are separated by a semicolon!
#
src_id;src_name;res;fps
EOF

# Function to extract metadata using ffprobe
extract_metadata() {
    local file="$1"

    # Get resolution and FPS using ffprobe
    local metadata
    # metadata=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate \
    metadata=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate \
               -of csv=p=0 "$file")

    # Extract resolution and FPS
    local width=$(echo "$metadata" | cut -d',' -f1)
    local height=$(echo "$metadata" | cut -d',' -f2)
    local fps=$(echo "$metadata" | cut -d',' -f3 | bc) # Convert FPS to decimal if needed
    # local fps=$(echo "$metadata" | cut -d',' -f3) # Convert FPS to decimal if needed

    # Print the result to the temp file
    echo "$(basename "$file");${width}x${height};$fps" >> "$TMP_FILE"
}

export -f extract_metadata
export TMP_FILE

# Use parallel to process files in parallel
find "$INPUT_DIR" -type f | sort | parallel -j "$(nproc)" extract_metadata {}

# Add ID column and sort the output
awk -F';' 'BEGIN {OFS=";"} {print NR, $0}' "$TMP_FILE" >> "$OUTPUT_FILE"

# Clean up
rm "$TMP_FILE"

echo "CSV output saved to $OUTPUT_FILE"
