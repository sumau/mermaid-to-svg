#!/usr/bin/env bash
#
# Render every Mermaid source under mermaid/source/ to an SVG under
# mermaid/generated/, using the pinned mermaid-cli Docker image.
#
# CI runs this and commits the result back to the branch, so contributors need
# nothing installed — just push text. You can also run it locally (Docker is the
# only dependency) to preview what CI will produce.
#
# Usage: ./render.sh

set -euo pipefail

IMAGE="minlag/mermaid-cli:11.16.0"
SOURCE_DIR="mermaid/source"
OUTPUT_DIR="mermaid/generated"
TEMP_DIR=".mermaid-tmp"
CONFIG="mermaid/config.json"

# Run mmdc inside the image, with the repo mounted at /data (the image's
# workdir). -u keeps generated files owned by the host user, not root.
mmdc_in_image() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD":/data "$IMAGE" "$@"
}

# Run the bundled Node (for Markdown extraction) inside the same image.
node_in_image() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD":/data --entrypoint node "$IMAGE" "$@"
}

sources_file="$(mktemp)"
map_file="$(mktemp)"
trap 'rm -f "$sources_file" "$map_file"; rm -rf "$TEMP_DIR"' EXIT

find "$SOURCE_DIR" \( -name '*.mmd' -o -name '*.mermaid' -o -name '*.md' \) \
  | sort > "$sources_file"

# Map each source to its output and fail on any collision (two sources that
# would produce the same .svg). No associative arrays, so this stays portable
# to the older Bash that ships on macOS.
while IFS= read -r src; do
  rel="${src#"$SOURCE_DIR"/}"
  printf '%s\t%s\n' "$OUTPUT_DIR/${rel%.*}.svg" "$src" >> "$map_file"
done < "$sources_file"

dupes="$(cut -f1 "$map_file" | sort | uniq -d || true)"
if [ -n "$dupes" ]; then
  echo "Error: output collision — rename one source so each produces a unique .svg:" >&2
  while IFS= read -r out; do
    echo "  $out <-" >&2
    awk -F'\t' -v o="$out" '$1==o { print "    " $2 }' "$map_file" >&2
  done <<< "$dupes"
  exit 1
fi

# Render each source. Markdown is first extracted to a temporary .mmd.
rm -rf "$TEMP_DIR"
while IFS= read -r src; do
  rel="${src#"$SOURCE_DIR"/}"
  out="$OUTPUT_DIR/${rel%.*}.svg"
  mkdir -p "$(dirname "$out")"

  case "$src" in
    *.md)
      input="$TEMP_DIR/${rel%.md}.mmd"
      mkdir -p "$(dirname "$input")"
      node_in_image scripts/extract-mermaid.mjs "$src" "$input"
      if [ ! -s "$input" ]; then
        echo "No mermaid block in $src; skipping"
        continue
      fi
      ;;
    *)
      input="$src"
      ;;
  esac

  echo "Rendering $input -> $out"
  # No -p: the pinned image ships its own /puppeteer-config.json (system
  # Chromium + --no-sandbox) and passes it by default.
  mmdc_in_image -c "$CONFIG" -i "$input" -o "$out"
done < "$sources_file"

# Remove generated SVGs whose source no longer exists.
if [ -d "$OUTPUT_DIR" ]; then
  find "$OUTPUT_DIR" -name '*.svg' | while IFS= read -r svg; do
    base="${svg#"$OUTPUT_DIR"/}"; base="${base%.svg}"
    if [ ! -f "$SOURCE_DIR/$base.md" ] \
      && [ ! -f "$SOURCE_DIR/$base.mmd" ] \
      && [ ! -f "$SOURCE_DIR/$base.mermaid" ]; then
      echo "Removing orphaned SVG: $svg"
      rm "$svg"
    fi
  done
  find "$OUTPUT_DIR" -type d -empty -delete
fi

echo "Done."
