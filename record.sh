#!/bin/bash
set -e

RTSP_URL="${RTSP_URL}"
output_folder="./videos"
chunk_duration="300"   # 每段 5 分钟
output_pattern="$output_folder/%Y-%m-%d-%H-%M-%S.mkv"
PID_FILE="/tmp/ffmpeg_pid.txt"

mkdir -p "$output_folder"

# 检查 RTSP 流是否可用的函数
check_stream2() {
}

PID_FILE="/tmp/ffmpeg_pid.txt"

start_recording() {
  ffmpeg -hide_banner -loglevel error -i "$RTSP_URL" -acodec copy -vcodec copy -f segment -segment_time "$chunk_duration" -reset_timestamps 1 -strftime 1 "$output_pattern" &
  echo $! > "$PID_FILE"
}

is_ffmpeg_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            return 0  # ffmpeg 进程正在运行
        fi
    fi
    return 1  # 没有 ffmpeg 进程在运行
}

kill_ffmpeg() {
    if is_ffmpeg_running; then
        PID=$(cat "$PID_FILE")
        kill -9 $PID
        echo "Killed previous ffmpeg process (PID: $PID)"
        rm "$PID_FILE"
    fi
}

# 后台监控文件夹并上传到 Google Drive
upload_loop() {
  echo "启动上传进程..."
  inotifywait -m -e close_write --format '%w%f' "$output_folder" | while read FILE
  do
    echo "检测到新文件: $FILE"
    rclone move "$FILE" "gdrive:rtsp-videos/" --progress
  done
}

# 启动上传后台任务
upload_loop &

while true; do
  echo "while start check!!!!"
  if check_stream2; then
    echo "ok"
      if ! is_ffmpeg_running; then
            echo "RTSP stream available, starting recording..."
            start_recording
      else
            echo "RTSP stream available, recording is already running."
      fi 
  else
    echo "error"
    kill_ffmpeg
  fi
  sleep 5
done
