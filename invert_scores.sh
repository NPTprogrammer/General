#!/usr/bin/env bash
#
# invert-scores.sh
#
# Purpose:
#   Recolor scanned score images into a two-tone scheme for video:
#     - Background -> #000917 (dark navy/black)
#     - Notes/Text -> #8e8780 (warm gray)
#
# Why:
#   - Improves readability on screen
#   - Discourages screenshot-as-PDF copying
#   - Makes the use more "transformative" for teaching
#
# Usage (basic):
#   chmod +x invert-scores.sh
#   ./invert-scores.sh
#
# Usage (custom):
#   ./invert-scores.sh --bg "#111216" --fg "#bdb6ae" --threshold 60
#   ./invert-scores.sh --fuzz 12
#   ./invert-scores.sh --outdir inverted_image
#   ./invert-scores.sh --ext "png,jpg,tif"
#   ./invert-scores.sh --dry-run
#
# Notes:
#   - Processes files in the current directory
#   - Saves to ./inverted_image with "_inverted" suffix
#   - Needs ImageMagick (`magick` or `convert`)
#

set -euo pipefail

# Defaults
BG_COLOR="#000917"
FG_COLOR="#8e8780"
OUTDIR="inverted_image"
MODE="threshold"   # "threshold" or "fuzz"
THRESHOLD="50"
FUZZ="0"
EXT_LIST="png,jpg,jpeg,tif,tiff"
DRY_RUN=0
VERBOSE=1

log() { [ "$VERBOSE" -eq 1 ] && echo -e "$*"; }
die() { echo "Error: $*" >&2; exit 1; }

show_help() {
  cat <<EOF
invert-scores.sh — recolor score images to a two-tone scheme

USAGE:
  ./invert-scores.sh [options]

OPTIONS:
  --bg "#RRGGBB"   Background color (default: $BG_COLOR)
  --fg "#RRGGBB"   Foreground/text color (default: $FG_COLOR)
  --threshold N    Threshold mode at N% (default: $THRESHOLD)
  --fuzz N         Fuzz mode at N% (default: $FUZZ)
  --ext "a,b,..."  Extensions (default: $EXT_LIST)
  --outdir NAME    Output directory (default: $OUTDIR)
  --dry-run        Show commands, do not run
  --quiet          Minimal output
  -h, --help       Show this help

WORKFLOWS:
  Threshold: grayscale -> binarize -> map white->BG, black->FG
  Fuzz: grayscale -> fuzzy recolor near-white/near-black

EOF
}

# Parse args
while (( "$#" )); do
  case "$1" in
    --bg) BG_COLOR="${2:?}"; shift 2 ;;
    --fg) FG_COLOR="${2:?}"; shift 2 ;;
    --threshold) MODE="threshold"; THRESHOLD="${2:?}"; shift 2 ;;
    --fuzz) MODE="fuzz"; FUZZ="${2:?}"; shift 2 ;;
    --ext) EXT_LIST="${2:?}"; shift 2 ;;
    --outdir) OUTDIR="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --quiet) VERBOSE=0; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) die "Unknown option: $1 (see --help)";;
  esac
done

# Detect ImageMagick
if command -v magick >/dev/null 2>&1; then
  IM_CMD=(magick)
elif command -v convert >/dev/null 2>&1; then
  IM_CMD=(convert)
else
  die "ImageMagick not found. Install and retry."
fi

# Collect files
IFS=',' read -r -a exts <<< "$EXT_LIST"
shopt -s nullglob nocaseglob
files=()
for ext in "${exts[@]}"; do files+=( *."$ext" ); done
shopt -u nocaseglob
[ "${#files[@]}" -gt 0 ] || die "No images found ($EXT_LIST)"

# Prepare output
mkdir -p "$OUTDIR"

log "== Invert Scores =="
log "Mode: $MODE"
log "BG:   $BG_COLOR"
log "FG:   $FG_COLOR"
log "Out:  $OUTDIR"
log "Exts: $EXT_LIST"
[ "$DRY_RUN" -eq 1 ] && log "(Dry run only)"

# Process files
for file in "${files[@]}"; do
  base="${file%.*}"
  ext="${file##*.}"
  out="${OUTDIR}/${base}_inverted.${ext}"

  log "Processing: $file -> $out"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "${IM_CMD[@]} $file ... $out"
    continue
  fi

  if [ "$MODE" = "threshold" ]; then
    "${IM_CMD[@]}" "$file" \
      -alpha off -colorspace Gray \
      -threshold "${THRESHOLD}%" \
      -fill "$BG_COLOR" -opaque white \
      -fill "$FG_COLOR" -opaque black \
      "$out"
  else
    "${IM_CMD[@]}" "$file" \
      -alpha off -colorspace Gray \
      -fuzz "${FUZZ}%" \
      -fill "$BG_COLOR" -opaque white \
      -fill "$FG_COLOR" -opaque black \
      "$out"
  fi
done

log "Done! Output saved in $OUTDIR"

