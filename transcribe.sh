#!/usr/bin/env bash
set -euo pipefail

MODEL_PATH="${WHISPER_MODEL:-ggml-large-v3.bin}"
WHISPER_BIN="${WHISPER_BIN:-/opt/homebrew/bin/whisper-cli}"
URL="${1:-}"
OUTPUT_NAME="${2:-lecture}"

if [[ "$OSTYPE" == "darwin"* ]]; then
  THREADS=$(sysctl -n hw.logicalcpu)
else
  THREADS=$(nproc 2>/dev/null || echo 4)
fi

if [ -z "$URL" ]; then
  echo "Использование: $0 \"<URL_YOUTUBE>\" [имя_файла]"
  exit 1
fi

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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

AUDIO_TMP="${TMP_DIR}/audio.wav"
TRANSCRIPT_TMP="${TMP_DIR}/output"

echo "==> [1/2] Загрузка и конвертация аудио (16kHz Mono PCM)..."
yt-dlp -4 \
  --extractor-args "youtube:player_client=android" \
  -x --audio-format wav \
  --postprocessor-args "ExtractAudio:-ar 16000 -ac 1 -c:a pcm_s16le" \
  "$URL" \
  -o "$AUDIO_TMP"

echo "==> [2/2] Транскрибация (${THREADS} потоков)..."
"$WHISPER_BIN" \
  -m "$MODEL_PATH" \
  -f "$AUDIO_TMP" \
  -of "$TRANSCRIPT_TMP" \
  -otxt \
  -t "$THREADS" \
  --language ru \
  --prompt "Транскрипция доклада и лекции." \
  --max-context 0 \
  --entropy-thold 2.4 \
  --logprob-thold -0.8 \
  --no-speech-thold 0.7 \
  --suppress-nst \
  --flash-attn

mv "${TRANSCRIPT_TMP}.txt" "${OUTPUT_NAME}.txt"

echo "==> Готово! Результат сохранен в ${OUTPUT_NAME}.txt"
