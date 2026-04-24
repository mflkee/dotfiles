#!/usr/bin/env bash

set -o noclobber -o noglob -o pipefail
IFS=$'\n'

FILE_PATH="${1}"
PV_WIDTH="${2:-120}"
PV_HEIGHT="${3:-40}"
IMAGE_CACHE_PATH="${4:-/tmp/ranger-preview.png}"
PV_IMAGE_ENABLED="${5:-False}"

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"

has() {
  command -v "$1" >/dev/null 2>&1
}

print_metadata() {
  if has exiftool; then
    exiftool -- "$FILE_PATH" && exit 5
  fi

  if has mediainfo; then
    mediainfo -- "$FILE_PATH" && exit 5
  fi
}

preview_text() {
  if has bat; then
    bat --color=always --style=numbers --line-range :600 -- "$FILE_PATH" && exit 5
  fi

  exit 2
}

preview_chafa() {
  local image_path="$1"

  if ! has chafa; then
    return 1
  fi

  chafa --animate=off --polite=on --symbols=block --fill=block \
    --size "${PV_WIDTH}x${PV_HEIGHT}" -- "$image_path" && exit 4
}

preview_magick_blocks() {
  local image_path="$1"
  local width="$PV_WIDTH"
  local height="$PV_HEIGHT"

  has magick || return 1

  (( width > 120 )) && width=120
  (( height > 60 )) && height=60
  (( height > 2 )) && height=$((height - 2))

  magick "$image_path" -auto-orient -thumbnail "${width}x${height}" \
    -background black -alpha remove -depth 8 txt:- 2>/dev/null |
    awk -F '[,(): ]+' '
      NR == 1 { next }
      NF >= 5 {
        y = $2
        if (seen && y != last_y) {
          printf "\033[0m\n"
        }
        printf "\033[48;2;%s;%s;%sm ", $3, $4, $5
        last_y = y
        seen = 1
      }
      END {
        if (seen) {
          printf "\033[0m\n"
        }
      }
    ' && exit 4
}

preview_pdf_image() {
  has pdftoppm || return 1

  local cache_base="${IMAGE_CACHE_PATH%.*}"
  pdftoppm -f 1 -l 1 -singlefile -png -scale-to-x 1600 -scale-to-y -1 \
    -- "$FILE_PATH" "$cache_base" >/dev/null 2>&1 || return 1

  local rendered="${cache_base}.png"
  [[ -s "$rendered" ]] || return 1

  if [[ "$PV_IMAGE_ENABLED" == "True" ]]; then
    mv -- "$rendered" "$IMAGE_CACHE_PATH" 2>/dev/null || cp -- "$rendered" "$IMAGE_CACHE_PATH"
    exit 6
  fi

  preview_chafa "$rendered"
  preview_magick_blocks "$rendered"
}

preview_video_image() {
  has ffmpegthumbnailer || return 1

  ffmpegthumbnailer -i "$FILE_PATH" -o "$IMAGE_CACHE_PATH" -s 0 -q 8 >/dev/null 2>&1 || return 1

  if [[ "$PV_IMAGE_ENABLED" == "True" ]]; then
    exit 6
  fi

  preview_chafa "$IMAGE_CACHE_PATH"
  preview_magick_blocks "$IMAGE_CACHE_PATH"
}

handle_extension() {
  case "$FILE_EXTENSION_LOWER" in
    7z)
      has 7z && 7z l -p -- "$FILE_PATH" && exit 5
      ;;
    a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|rar|rpm|rz|tar|tbz|tbz2|tgz|tlz|txz|xz|zip|zst)
      has atool && atool --list -- "$FILE_PATH" && exit 5
      has bsdtar && bsdtar --list --file "$FILE_PATH" && exit 5
      ;;
    pdf)
      preview_pdf_image
      pdftotext -l 10 -nopgbrk -q -- "$FILE_PATH" - | fmt -w "$PV_WIDTH" && exit 5
      print_metadata
      ;;
    json)
      jq --color-output . "$FILE_PATH" && exit 5
      python -m json.tool -- "$FILE_PATH" && exit 5
      ;;
    htm|html|xhtml)
      if has w3m; then
        w3m -dump "$FILE_PATH" && exit 5
      fi
      ;;
    odt|ods|odp|doc|docx|xls|xlsx|ppt|pptx)
      if has libreoffice; then
        local tmpdir
        local converted
        tmpdir="$(mktemp -d)"
        libreoffice --headless --convert-to txt --outdir "$tmpdir" "$FILE_PATH" >/dev/null 2>&1
        converted="$(find "$tmpdir" -type f -name '*.txt' -print -quit)"
        [[ -n "$converted" ]] && sed -n '1,200p' "$converted" && exit 5
      fi
      ;;
    torrent)
      transmission-show -- "$FILE_PATH" && exit 5
      ;;
  esac
}

handle_mime() {
  local mimetype="$1"

  case "$mimetype" in
    image/*)
      if [[ "$PV_IMAGE_ENABLED" == "True" ]]; then
        exit 7
      fi

      preview_chafa "$FILE_PATH"
      preview_magick_blocks "$FILE_PATH"
      identify -verbose -- "$FILE_PATH" 2>/dev/null | sed -n '1,80p' && exit 5
      print_metadata
      ;;
    video/*)
      preview_video_image
      print_metadata
      ;;
    audio/*)
      print_metadata
      ;;
    application/pdf)
      preview_pdf_image
      pdftotext -l 10 -nopgbrk -q -- "$FILE_PATH" - | fmt -w "$PV_WIDTH" && exit 5
      ;;
    text/*|application/json|application/xml|application/javascript|application/x-shellscript)
      preview_text
      ;;
  esac
}

handle_extension

MIMETYPE="$(file --dereference --brief --mime-type -- "$FILE_PATH" 2>/dev/null || true)"
handle_mime "$MIMETYPE"

print_metadata
file --brief -- "$FILE_PATH" 2>/dev/null && exit 5
exit 1
