#!/bin/bash

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "FFmpeg could not be found. Please install it first."
    exit 1
fi

# Check if FFprobe is installed
if ! command -v ffprobe &> /dev/null; then
    echo "FFprobe could not be found. Please install it first."
    exit 1
fi

# Check if a directory is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Directory containing MP4 files
SOURCE_DIR="$1"

# Find all MP4 files in the source directory and its subdirectories
find "$SOURCE_DIR" -type f -name "*.mp4" | while read -r mp4_file; do
    # Get the base name of the file without extension
    base_name=$(basename "${mp4_file%.*}")

    # Directory where the MP4 file is located
    output_dir="$(dirname "$mp4_file")"

    # Create mkv subdirectory if it doesn't exist
    mkv_output_dir="${output_dir}/mkv"
    mkdir -p "$mkv_output_dir"

    # Output MKV file path
    mkv_file="${mkv_output_dir}/${base_name}.mkv"

    echo "Converting '$mp4_file' to '$mkv_file'"

    # Get video duration using ffprobe
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$mp4_file")
    export duration

    # Remux MP4 to MKV using ffmpeg with progress indicator
    ffmpeg -i "$mp4_file" -c copy -y -loglevel error -progress pipe:1 "$mkv_file" | {
        while IFS= read -r line; do
            if [[ $line =~ out_time_ms=([0-9]+) ]]; then
                current_time_ms="${BASH_REMATCH[1]}"
                # Calculate progress percentage
                current_sec=$(awk "BEGIN {print $current_time_ms / 1000000}")
                percent=$(awk "BEGIN {printf \"%.2f\", ($current_sec / $duration) * 100}")
                
                # Create progress bar
                width=50
                filled=$(awk "BEGIN {printf \"%d\", ($percent / 100) * $width}")
                printf -v bar "%*s" "$filled" ""
                bar=${bar// /#}
                printf -v empty "%*s" "$((width - filled))" ""
                printf "\r[%s%s] %.2f%%" "$bar" "$empty" "$percent"
            fi
        done
        printf "\n"
    }

    # Check if conversion was successful
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "Conversion successful: '$mp4_file' -> '$mkv_file'"
    else
        echo "Conversion failed for: '$mp4_file'"
    fi
done
