#!/usr/bin/env bash
# craft-defaults.sh — делает приложения ArtCraft системными обработчиками
# «своих» файловых типов.
#
# Что делает:
#   1) прописывает MimeType= в .desktop-файлы приложений, если они лежат
#      per-user (~/.local/share/applications/ai.storyteller.*.desktop — так их
#      пишет ArtCraft Launcher, и при обновлении он MimeType теряет).
#      При установке из pacman-репозитория пакеты уже несут MimeType в
#      /usr/share/applications — там скрипт ничего не трогает (только читает);
#   2) назначает xdg-mime по умолчанию (~/.config/mimeapps.list);
#   3) обновляет кэш desktop-файлов.
#
# Скрипт идемпотентный: повторный запуск ничего не ломает и показывает, что
# уже стоит на месте.
#
# Запуск:
#   craft-defaults.sh            — применить
#   craft-defaults.sh --dry-run  — только показать план
#   craft-defaults.sh --check    — показать текущее состояние (не менять)
set -euo pipefail

USER_APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
SYSTEM_APPS=/usr/share/applications
MODE="${1:-}"

# ─── какие форматы приложение раскрывает в «Open with» ────────────────────────
# desktop-id|MimeType (официальный список форматов приложения + его собственные)
DESKTOPS=(
  'ai.storyteller.anicraft.desktop|application/x-anicraft;application/x-fla;application/x-xfl;'
  'ai.storyteller.cadcraft.desktop|image/vnd.dxf;image/vnd.dwg;application/x-dxf;application/acad;'
  'ai.storyteller.deckcraft.desktop|application/x-deckcraft;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/vnd.openxmlformats-officedocument.presentationml.template;application/vnd.openxmlformats-officedocument.presentationml.slideshow;'
  'ai.storyteller.designcraft.desktop|application/x-designcraft;application/vnd.adobe.indesign-idml-package;'
  'ai.storyteller.figcraft.desktop|application/x-figcraft;application/x-sketch;image/svg+xml;image/png;image/jpeg;x-scheme-handler/figcraft;'
  'ai.storyteller.filmcraft.desktop|application/x-filmcraft;video/mp4;video/x-m4v;video/quicktime;video/x-matroska;video/webm;video/vnd.avi;video/x-msvideo;application/mxf;video/mp2t;video/mpeg;video/3gpp;'
  'ai.storyteller.lightcraft.desktop|image/heic;image/heif;image/jpeg;image/png;image/tiff;image/webp;image/x-adobe-dng;image/x-sony-arw;image/x-canon-cr2;image/x-canon-cr3;image/x-nikon-nef;image/x-fuji-raf;image/x-olympus-orf;image/x-panasonic-rw2;image/x-panasonic-rw;image/x-pentax-pef;'
  'ai.storyteller.materialcraft.desktop|application/x-materialcraft;'
  'ai.storyteller.pdfcraft.desktop|application/pdf;'
  'ai.storyteller.photocraft.desktop|application/x-photocraft;image/x-paintnet;image/openraster;application/x-krita;image/vnd.adobe.photoshop;image/x-psd;image/x-psb;image/png;image/jpeg;image/tiff;image/webp;image/gif;image/bmp;image/x-tga;image/x-icon;image/vnd.microsoft.icon;image/x-portable-anymap;image/x-portable-bitmap;image/x-portable-graymap;image/x-portable-pixmap;image/x-exr;image/vnd.radiance;image/avif;image/qoi;'
  'ai.storyteller.soundcraft.desktop|application/x-soundcraft-session;audio/x-wav;audio/wav;audio/vnd.wave;audio/x-aiff;audio/aiff;audio/flac;audio/x-flac;audio/mpeg;audio/midi;audio/x-midi;'
  'ai.storyteller.texturecraft.desktop|application/x-texturecraft;model/gltf-binary;model/gltf+json;model/x-fbx;model/vnd.collada+xml;model/x-usd;model/vnd.usda;model/vnd.usdz+zip;model/x-alembic;model/obj;model/x-ply;model/stl;'
  'ai.storyteller.vectorcraft.desktop|image/svg+xml;image/svg+xml-compressed;application/x-vectorcraft;application/x-vectorcraft-template;application/illustrator;application/x-ai-template;application/x-affinity;image/emf;image/wmf;image/x-eps;application/pdf;'
  'ai.storyteller.wordcraft.desktop|application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.ms-word.document.macroEnabled.12;application/vnd.openxmlformats-officedocument.wordprocessingml.template;application/vnd.ms-word.template.macroEnabled.12;application/msword;application/msword-template;application/vnd.oasis.opendocument.text;application/rtf;text/rtf;text/markdown;text/x-tex;text/html;text/plain;'
)

# ─── что ставим по умолчанию (mime|desktop-id) ────────────────────────────────
# Конфликты разрешены так: картинки (png/jpeg/tiff/webp/gif/…) → PhotoCraft,
# RAW и HEIC → LightCraft, pdf → PdfCraft, svg → VectorCraft, видео → FilmCraft,
# аудио → SoundCraft, 3D-модели → TextureCraft, dxf/dwg → CadCraft.
# text/plain, text/html и text/markdown сознательно НЕ перехватываем (см. KEEP).
DEFAULTS=(
  # AniCraft
  'application/x-anicraft|ai.storyteller.anicraft.desktop'
  'application/x-fla|ai.storyteller.anicraft.desktop'
  'application/x-xfl|ai.storyteller.anicraft.desktop'
  # CadCraft
  'image/vnd.dxf|ai.storyteller.cadcraft.desktop'
  'image/vnd.dwg|ai.storyteller.cadcraft.desktop'
  'application/x-dxf|ai.storyteller.cadcraft.desktop'
  'application/acad|ai.storyteller.cadcraft.desktop'
  # DeckCraft
  'application/x-deckcraft|ai.storyteller.deckcraft.desktop'
  'application/vnd.openxmlformats-officedocument.presentationml.presentation|ai.storyteller.deckcraft.desktop'
  'application/vnd.openxmlformats-officedocument.presentationml.template|ai.storyteller.deckcraft.desktop'
  'application/vnd.openxmlformats-officedocument.presentationml.slideshow|ai.storyteller.deckcraft.desktop'
  # DesignCraft
  'application/x-designcraft|ai.storyteller.designcraft.desktop'
  'application/vnd.adobe.indesign-idml-package|ai.storyteller.designcraft.desktop'
  # FigCraft (только собственные форматы + его схема; svg/png остаются за другими)
  'application/x-figcraft|ai.storyteller.figcraft.desktop'
  'application/x-sketch|ai.storyteller.figcraft.desktop'
  'x-scheme-handler/figcraft|ai.storyteller.figcraft.desktop'
  # FilmCraft
  'application/x-filmcraft|ai.storyteller.filmcraft.desktop'
  'video/mp4|ai.storyteller.filmcraft.desktop'
  'video/x-m4v|ai.storyteller.filmcraft.desktop'
  'video/quicktime|ai.storyteller.filmcraft.desktop'
  'video/x-matroska|ai.storyteller.filmcraft.desktop'
  'video/webm|ai.storyteller.filmcraft.desktop'
  'video/vnd.avi|ai.storyteller.filmcraft.desktop'
  'video/x-msvideo|ai.storyteller.filmcraft.desktop'
  'application/mxf|ai.storyteller.filmcraft.desktop'
  'video/mp2t|ai.storyteller.filmcraft.desktop'
  'video/mpeg|ai.storyteller.filmcraft.desktop'
  'video/3gpp|ai.storyteller.filmcraft.desktop'
  # GridCraft
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet|ai.storyteller.gridcraft.desktop'
  'application/vnd.ms-excel.sheet.macroEnabled.12|ai.storyteller.gridcraft.desktop'
  'application/vnd.ms-excel.sheet.binary.macroEnabled.12|ai.storyteller.gridcraft.desktop'
  'application/vnd.oasis.opendocument.spreadsheet|ai.storyteller.gridcraft.desktop'
  'text/csv|ai.storyteller.gridcraft.desktop'
  'text/tab-separated-values|ai.storyteller.gridcraft.desktop'
  # LightCraft (RAW + HEIC; jpeg/png/tiff/webp остаются за PhotoCraft)
  'image/heic|ai.storyteller.lightcraft.desktop'
  'image/heif|ai.storyteller.lightcraft.desktop'
  'image/x-adobe-dng|ai.storyteller.lightcraft.desktop'
  'image/x-sony-arw|ai.storyteller.lightcraft.desktop'
  'image/x-canon-cr2|ai.storyteller.lightcraft.desktop'
  'image/x-canon-cr3|ai.storyteller.lightcraft.desktop'
  'image/x-nikon-nef|ai.storyteller.lightcraft.desktop'
  'image/x-fuji-raf|ai.storyteller.lightcraft.desktop'
  'image/x-olympus-orf|ai.storyteller.lightcraft.desktop'
  'image/x-panasonic-rw2|ai.storyteller.lightcraft.desktop'
  'image/x-panasonic-rw|ai.storyteller.lightcraft.desktop'
  'image/x-pentax-pef|ai.storyteller.lightcraft.desktop'
  # MaterialCraft
  'application/x-materialcraft|ai.storyteller.materialcraft.desktop'
  # PdfCraft
  'application/pdf|ai.storyteller.pdfcraft.desktop'
  # PhotoCraft
  'application/x-photocraft|ai.storyteller.photocraft.desktop'
  'image/x-paintnet|ai.storyteller.photocraft.desktop'
  'image/openraster|ai.storyteller.photocraft.desktop'
  'application/x-krita|ai.storyteller.photocraft.desktop'
  'image/vnd.adobe.photoshop|ai.storyteller.photocraft.desktop'
  'image/x-psd|ai.storyteller.photocraft.desktop'
  'image/x-psb|ai.storyteller.photocraft.desktop'
  'image/png|ai.storyteller.photocraft.desktop'
  'image/jpeg|ai.storyteller.photocraft.desktop'
  'image/tiff|ai.storyteller.photocraft.desktop'
  'image/webp|ai.storyteller.photocraft.desktop'
  'image/gif|ai.storyteller.photocraft.desktop'
  'image/bmp|ai.storyteller.photocraft.desktop'
  'image/x-tga|ai.storyteller.photocraft.desktop'
  'image/x-icon|ai.storyteller.photocraft.desktop'
  'image/vnd.microsoft.icon|ai.storyteller.photocraft.desktop'
  'image/x-portable-anymap|ai.storyteller.photocraft.desktop'
  'image/x-portable-bitmap|ai.storyteller.photocraft.desktop'
  'image/x-portable-graymap|ai.storyteller.photocraft.desktop'
  'image/x-portable-pixmap|ai.storyteller.photocraft.desktop'
  'image/x-exr|ai.storyteller.photocraft.desktop'
  'image/vnd.radiance|ai.storyteller.photocraft.desktop'
  'image/avif|ai.storyteller.photocraft.desktop'
  'image/qoi|ai.storyteller.photocraft.desktop'
  # SoundCraft
  'application/x-soundcraft-session|ai.storyteller.soundcraft.desktop'
  'audio/x-wav|ai.storyteller.soundcraft.desktop'
  'audio/wav|ai.storyteller.soundcraft.desktop'
  'audio/vnd.wave|ai.storyteller.soundcraft.desktop'
  'audio/x-aiff|ai.storyteller.soundcraft.desktop'
  'audio/aiff|ai.storyteller.soundcraft.desktop'
  'audio/flac|ai.storyteller.soundcraft.desktop'
  'audio/x-flac|ai.storyteller.soundcraft.desktop'
  'audio/mpeg|ai.storyteller.soundcraft.desktop'
  'audio/midi|ai.storyteller.soundcraft.desktop'
  'audio/x-midi|ai.storyteller.soundcraft.desktop'
  # TextureCraft (3D-модели)
  'application/x-texturecraft|ai.storyteller.texturecraft.desktop'
  'model/gltf-binary|ai.storyteller.texturecraft.desktop'
  'model/gltf+json|ai.storyteller.texturecraft.desktop'
  'model/x-fbx|ai.storyteller.texturecraft.desktop'
  'model/vnd.collada+xml|ai.storyteller.texturecraft.desktop'
  'model/x-usd|ai.storyteller.texturecraft.desktop'
  'model/vnd.usda|ai.storyteller.texturecraft.desktop'
  'model/vnd.usdz+zip|ai.storyteller.texturecraft.desktop'
  'model/x-alembic|ai.storyteller.texturecraft.desktop'
  'model/obj|ai.storyteller.texturecraft.desktop'
  'model/x-ply|ai.storyteller.texturecraft.desktop'
  'model/stl|ai.storyteller.texturecraft.desktop'
  # VectorCraft
  'image/svg+xml|ai.storyteller.vectorcraft.desktop'
  'image/svg+xml-compressed|ai.storyteller.vectorcraft.desktop'
  'application/x-vectorcraft|ai.storyteller.vectorcraft.desktop'
  'application/x-vectorcraft-template|ai.storyteller.vectorcraft.desktop'
  'application/illustrator|ai.storyteller.vectorcraft.desktop'
  'application/x-ai-template|ai.storyteller.vectorcraft.desktop'
  'application/x-affinity|ai.storyteller.vectorcraft.desktop'
  'image/emf|ai.storyteller.vectorcraft.desktop'
  'image/wmf|ai.storyteller.vectorcraft.desktop'
  'image/x-eps|ai.storyteller.vectorcraft.desktop'
  # WordCraft (text/plain, text/html, text/markdown сознательно НЕ перехватываем)
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document|ai.storyteller.wordcraft.desktop'
  'application/vnd.ms-word.document.macroEnabled.12|ai.storyteller.wordcraft.desktop'
  'application/vnd.openxmlformats-officedocument.wordprocessingml.template|ai.storyteller.wordcraft.desktop'
  'application/vnd.ms-word.template.macroEnabled.12|ai.storyteller.wordcraft.desktop'
  'application/msword|ai.storyteller.wordcraft.desktop'
  'application/msword-template|ai.storyteller.wordcraft.desktop'
  'application/vnd.oasis.opendocument.text|ai.storyteller.wordcraft.desktop'
  'application/rtf|ai.storyteller.wordcraft.desktop'
  'text/rtf|ai.storyteller.wordcraft.desktop'
  'text/x-tex|ai.storyteller.wordcraft.desktop'
)

# ─── форматы, которые НЕ должны уехать в Craft ───────────────────────────────
# mime|предпочтительный обработчик. Если сейчас стоит «не-craft» приложение —
# не трогаем (уважаем выбор пользователя); если стоит craft или пусто —
# выставляем предпочтительный.
KEEP=(
  'text/plain|nvim.desktop'
  'text/html|zen.desktop'
  'text/markdown|com.bilingify.readest.desktop'
)

say() { printf '%s\n' "$*"; }

is_craft() { [[ ${1:-} == ai.storyteller.*.desktop ]]; }

# desktop-файл существует (per-user или системный)
desktop_exists() { [[ -f $USER_APPS/$1 || -f $SYSTEM_APPS/$1 ]]; }

# mime реально закреплён пользователем в ~/.config/mimeapps.list
# (без pinned-записи `xdg-mime query default` отдаёт «первое рекомендованное»
# из mimeinfo.cache, а это не выбор пользователя)
is_pinned() {
  local mime="$1"
  [[ -f $HOME/.config/mimeapps.list ]] || return 1
  grep -qE "^[[:space:]]*$(printf '%s' "$mime" | sed 's/[.]/\\./g')=" "$HOME/.config/mimeapps.list"
}

# MimeType в .desktop: приложение (и «Open with», и xdg-mime) узнаёт о типах
patch_desktop() {
  local id="$1" mime="$2" f="$USER_APPS/$1"
  [[ -f $f ]] || return 0   # системная установка: MimeType уже в пакете
  if grep -qxF "MimeType=$mime" "$f"; then
    say "  = $id: MimeType уже на месте"
  elif [[ $MODE == --dry-run || $MODE == --check ]]; then
    say "  ~ $id: MimeType нужно прописать"
  else
    if grep -q '^MimeType=' "$f"; then
      sed -i "s|^MimeType=.*|MimeType=$mime|" "$f"
    else
      awk -v m="MimeType=$mime" '{print} /^Exec=/ && !done {print m; done=1} END {if (!done) print m}' \
        "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    fi
    say "  + $id: MimeType прописан"
  fi
  # figcraft умеет x-scheme-handler → ему нужен %U, а не %F
  if [[ $id == ai.storyteller.figcraft.desktop ]] && grep -q ' %F$' "$f"; then
    if [[ $MODE == --dry-run || $MODE == --check ]]; then
      say "  ~ $id: Exec нужно поменять %F → %U (есть x-scheme-handler)"
    else
      sed -i 's| %F$| %U|' "$f"
      say "  + $id: Exec → %U (обработчик ссылок figcraft://)"
    fi
  fi
}

set_default() {
  local mime="$1" id="$2" cur
  cur=$(xdg-mime query default "$mime" 2>/dev/null || true)
  if [[ $cur == "$id" ]]; then
    say "  = $mime → $id"
    return 0
  fi
  if [[ $MODE == --dry-run || $MODE == --check ]]; then
    say "  ~ $mime → $id  (сейчас: ${cur:-нет})"
    return 0
  fi
  if xdg-mime default "$id" "$mime"; then
    say "  + $mime → $id  (было: ${cur:-нет})"
  else
    say "  ! $mime → $id: xdg-mime отказался (нет $id.desktop?)"
  fi
}

say "── 1/4 MimeType в .desktop ($USER_APPS)"
if [[ -d $USER_APPS ]]; then
  for row in "${DESKTOPS[@]}"; do patch_desktop "${row%%|*}" "${row#*|}"; done
else
  say "  (каталога нет — приложения стоят системно, шаг пропущен)"
fi

say "── 2/4 значения по умолчанию (xdg-mime)"
for row in "${DEFAULTS[@]}"; do set_default "${row%%|*}" "${row#*|}"; done

say "── 3/4 форматы, которые остаются у прежних приложений"
for row in "${KEEP[@]}"; do
  mime="${row%%|*}"; id="${row#*|}"
  cur=$(xdg-mime query default "$mime" 2>/dev/null || true)
  if [[ $cur == "$id" ]]; then
    say "  = $mime → $id"
  elif is_pinned "$mime" && ! is_craft "$cur"; then
    say "  = $mime → $cur (закреплено пользователем, не craft)"
  elif ! desktop_exists "$id"; then
    say "  ! $mime: $id не установлен — оставляю ${cur:-пусто}"
  else
    set_default "$mime" "$id"
  fi
done

say "── 4/4 кэш desktop-файлов"
if [[ $MODE == --dry-run || $MODE == --check ]]; then
  say "  ~ update-desktop-database $USER_APPS"
else
  update-desktop-database -q "$USER_APPS" 2>/dev/null || update-desktop-database "$USER_APPS" 2>/dev/null || true
  say "  + update-desktop-database"
fi

say "готово."
