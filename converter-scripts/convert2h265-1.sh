#!/bin/bash

if [ $# -eq 0 ] || [ "$1" == "-h" ]; then
    echo "Convert a video file to HEVC (H.265) with a specified bitrate and copy the audio into a MKV container."
    echo "Usage: $0 <video_file> [bitrate]"
    echo "  -h, --help       Display this help message"
    echo "  <video_file>     Path to the input video file"
    echo "  [bitrate]        Output bitrate (default is 3M if not specified)"
    exit 0
fi

filename=$1
bitrate=${2:-3M}
extension="${filename##*.}"
basename="${filename%.*}"
output_file="$basename""_${bitrate}.mkv"

if [ ! -f "$filename" ]; then
    echo "File $filename not found."
    exit 1
fi

# Check if nvenc is enabled for HEVC encoding
nvenc_info=$(ffmpeg -hide_banner -encoders | grep hevc_nvenc)
if [ -n "$nvenc_info" ]; then
    echo "Using hardware acceleration (nvenc)"
    ffmpeg -hwaccel cuda -i "$filename" -c:v hevc_nvenc -b:v $bitrate -c:a copy "$output_file"
elif [ -n "$qsv_info" ]; then
    echo "Using hardware acceleration (Intel Quick Sync Video)"
    ffmpeg -hwaccel qsv -i "$filename" -c:v hevc_qsv -b:v $bitrate -c:a copy "$output_file"
elif [ -n "$vt_info" ]; then
    echo "Using hardware acceleration (Apple's GPU video acceleration)"
    ffmpeg -hwaccel videotoolbox -i "$filename" -c:v hevc_videotoolbox -b:v $bitrate -c:a copy "$output_file"
else
    echo "Hardware acceleration not available, using software encoding"
    ffmpeg -i "$filename" -c:v libx265 -b:v $bitrate -c:a copy "$output_file"
fi
