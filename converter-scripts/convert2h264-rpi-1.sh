#!/bin/bash

if [ $# -eq 0 ] || [ "$1" == "-h" ]; then
    echo "Convert a video file to H264 with a specified bitrate and copy the audio into a MKV container."
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

# Check if h264_v4l2m2m (Raspberry Pi hardware acceleration) is enabled for H.264 encoding
hwaccel_info=$(ffmpeg -hide_banner -encoders | grep h264_v4l2m2m)
if [ -n "$hwaccel_info" ]; then
    echo "Using hardware acceleration (h264_v4l2m2m)"
    ffmpeg -hwaccel v4l2m2m -i "$filename" -c:v h264_v4l2m2m -b:v $bitrate -c:a copy "$output_file"
else
    echo "Hardware acceleration not available, using software encoding"
    ffmpeg -i "$filename" -c:v libx264 -b:v $bitrate -c:a copy "$output_file"
fi
