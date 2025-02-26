#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
check_deps() {
    for cmd in streamlink curl; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            echo "Install with: sudo apt install $cmd"
            exit 1
        fi
    done
}

# Get timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Check if channel is live
is_live() {
    local channel=$1
    # Use curl to check stream status via Twitch's public API
    local status=$(curl -s -A "Mozilla/5.0" "https://www.twitch.tv/$channel" | grep -c "isLiveBroadcast")
    [ "$status" -gt 0 ] && return 0 || return 1
}

# Record stream using streamlink
record_stream() {
    local channel=$1
    local output_dir=$2
    local date_str=$(date +%Y%m%d_%H%M%S)
    local filename="$output_dir/${channel}_${date_str}.mp4"
    
    echo -e "${GREEN}[$(timestamp)] Recording ${BLUE}$channel${GREEN} to ${BLUE}${filename}${NC}"
    
    streamlink \
        --twitch-disable-ads \
        --twitch-disable-hosting \
        --retry-streams 30 \
        --retry-max 5 \
        --retry-open 5 \
        --stream-segment-threads 5 \
        --stream-timeout 90 \
        --hls-segment-threads 5 \
        -o "$filename" \
        "twitch.tv/$channel" best
}

# Main monitoring loop
monitor_channels() {
    local channels=("$@")
    local output_dir="recordings"
    local check_interval=60  # seconds
    declare -A recording_pids
    
    mkdir -p "$output_dir"
    
    echo -e "${YELLOW}Starting Twitch monitor${NC}"
    echo -e "Watching: ${BLUE}${channels[*]}${NC}"
    echo -e "Saving to: ${BLUE}$output_dir${NC}"
    echo -e "Checking every ${check_interval} seconds"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"
    
    while true; do
        for channel in "${channels[@]}"; do
            # Skip if already recording
            if [[ ${recording_pids[$channel]+_} ]]; then
                # Check if recording process is still running
                if ! kill -0 ${recording_pids[$channel]} 2>/dev/null; then
                    echo -e "${YELLOW}[$(timestamp)] Recording stopped for ${BLUE}$channel${NC}"
                    unset recording_pids[$channel]
                else
                    continue
                fi
            fi
            
            # Check if channel is live
            if is_live "$channel"; then
                if [[ ! ${recording_pids[$channel]+_} ]]; then
                    record_stream "$channel" "$output_dir" &
                    recording_pids[$channel]=$!
                    echo -e "${GREEN}[$(timestamp)] Started recording ${BLUE}$channel${NC} (PID: ${recording_pids[$channel]})"
                fi
            else
                echo -e "${YELLOW}[$(timestamp)] ${BLUE}$channel${NC} is offline"
            fi
        done
        
        sleep "$check_interval"
    done
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: Please provide channel names${NC}"
        echo "Usage: $0 channel1 [channel2 ...]"
        exit 1
    fi
    
    check_deps
    monitor_channels "$@"
}

# Handle script interruption
trap 'echo -e "\n${RED}Stopping monitor...${NC}"; kill $(jobs -p) 2>/dev/null; exit' INT TERM

# Start the script
main "$@"
