
#!/usr/bin/env bash
# hoyGarageRoofHydrant1: GIF of the aligned panoramas
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DATASET=hoyGarageRoofHydrant1
PANO="$DATA_ROOT/registered/$DATASET/images/pano_aligned"
OUT="$DATA_ROOT/trained/$DATASET"
VIDEOS="$OUT/videos"

FRAMES=()
while IFS= read -r -d '' frame; do
    FRAMES+=("$frame")
done < <(find "$PANO" -maxdepth 1 -type f -name '*.png' -print0 | sort -z)
if ((${#FRAMES[@]} == 0)); then
    echo "No panoramas in $PANO; run register_hoyg.sh first" >&2
    exit 1
fi

mkdir -p "$VIDEOS"

# Paths in the list are relative to the list file, so store absolute paths.
# A 1s duration per still, with the last file repeated, makes the concat
# demuxer emit one frame per panorama. premultiply composites alpha onto black.
LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT
for frame in "${FRAMES[@]}"; do
    abs=$(readlink -f "$frame")
    esc=${abs//\'/\'\\\'\'}
    printf "file '%s'\nduration 1\n" "$esc"
done > "$LIST"
abs=$(readlink -f "${FRAMES[-1]}")
esc=${abs//\'/\'\\\'\'}
printf "file '%s'\n" "$esc" >> "$LIST"

ffmpeg -hide_banner -y \
    -f concat -safe 0 -i "$LIST" \
    -vf "premultiply=inplace=1,format=rgb24,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black,select='not(mod(n\,5))',setpts=N/(6*TB),fps=6,scale=480:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=64:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
    "$VIDEOS/aligned_panos.gif" \
    2>&1 | tee -a "$OUT/panos.log"