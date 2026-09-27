#!/usr/bin/env bash
set -euo pipefail

# ubuntu-test keeps the Intel GPU runtime and model under /root/src/whisper.cpp.
# The source is a submodule in the Ubuntu distro, exposed through WSL's DrvFs.
source_dir=/mnt/ubuntu-t3setup
if ! mountpoint -q "$source_dir"; then
  mkdir -p "$source_dir"
  mount -t drvfs //wsl.localhost/Ubuntu/home/anton/t3setup "$source_dir"
fi

cd "$source_dir/voice"
export WHISPER_CPP_DIR=/root/src/whisper.cpp
exec python3 openvino/server.py --port "${T3_VOICE_PORT:-8001}"