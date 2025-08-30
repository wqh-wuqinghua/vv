#!/bin/bash
set -e

RTSP_URL="${RTSP_URL}"
output_folder="./videos"
chunk_duration="300"   # 每段 5 分钟
output_pattern="$output_folder/%Y-%m-%d-%H-%M-%S.mkv"
PID_FILE="/tmp/ffmpeg_pid.txt"

mkdir -p "$output_folder"

check_stream2() {
  output=$(ffmpeg -hide_banner -loglevel error -timeout 5000000 -rtsp_transport tcp -i "$RTSP_URL" -t 1 -f null - 2>&1)
  STATUS=$?

  if [[ $output == *"No route to host"* ]]; then
    return 1
  elif [[ $output == *"Connection refused"* ]]; then
    return 1
  elif [[ $output == *"Error opening input"* ]]; then
    return 1
  elif [ $STATUS -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

start_recording() {
  ffmpeg -hide_banner -loglevel error -rtsp_transport tcp -i "$RTSP_URL" \
    -acodec copy -vcodec copy \
    -f segment -segment_time "$chunk_duration" \
    -reset_timestamps 1 -strftime 1 "$output_pattern" &
  echo $! > "$PID_FILE"
}

is_ffmpeg_running() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

kill_ffmpeg() {
  if is_ffmpeg_running; then
    PID=$(cat "$PID_FILE")
    kill -9 $PID
    rm -f "$PID_FILE"
  fi
}

end_time=$((SECONDS + 6*3600))   # 最多运行 6 小时

while [ $SECONDS -lt $end_time ]; do
  if check_stream2; then
    if ! is_ffmpeg_running; then
      echo "RTSP available, starting recording..."
      start_recording
    fi
  else
    echo "RTSP unavailable, stopping recording..."
    kill_ffmpeg
  fi
  sleep 5
done

echo "Time limit reached, stopping..."
kill_ffmpeg
