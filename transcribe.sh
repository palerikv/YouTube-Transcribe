#!/usr/bin/env bash
set -euo pipefail

# --- Конфигурация по умолчанию ---
MODEL_PATH="${WHISPER_MODEL:-ggml-large-v3.bin}"
WHISPER_BIN="${WHISPER_BIN:-/opt/homebrew/bin/whisper-cli}"
URL="${1:-}"
OUTPUT_NAME="${2:-lecture}"

# Автоматическое определение потоков
if [[ "$OSTYPE" == "darwin"* ]]; then
  THREADS=$(sysctl -n hw.logicalcpu)
else
  THREADS=$(nproc 2>/dev/null || echo 4)
fi

# Проверка входных аргументов
if [ -z "$URL" ]; then
  echo "Использование: $0 <URL_YOUTUBE> [имя_файла]"
  exit 1
fi

# Проверка наличия зависимостей
for cmd in yt-dlp ffmpeg "$WHISPER_BIN"; do
  if ! command -v "$cmd" &>/dev/null && [ ! -x "$cmd" ]; then
    echo "Ошибка: утилита '$cmd' не найдена в системе."
    exit 1
  fi
done

if [ ! -f "$MODEL_PATH" ]; then
  echo "Ошибка: файл модели '$MODEL_PATH' не найден в текущей директории."
  echo "Скачайте модель: curl -L -O https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"
  exit 1
fi

# Создание временной рабочей директории
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

AUDIO_TMP="${TMP_DIR}/audio.wav"
TRANSCRIPT_TMP="${TMP_DIR}/output"

# 1. Загрузка и подготовка звука
echo "==> [1/2] Загрузка и конвертация аудио (16kHz Mono PCM)..."
yt-dlp -4 \
  --extractor-args