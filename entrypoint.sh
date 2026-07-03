#!/usr/bin/env bash
#
# Action entrypoint: render every Mermaid source under $SOURCE_DIR to an SVG
# under $OUTPUT_DIR, using the mermaid-cli tooling baked into this image. Runs
# inside the container with the consumer's repo mounted at the working
# directory. Configured via env (set from the action's inputs):
#
#   SOURCE_DIR  Mermaid sources (.mmd, .mermaid, .md)   [default mermaid/source]
#   OUTPUT_DIR  where SVGs are written                  [default mermaid/generated]
#   CONFIG      Mermaid config JSON for mmdc -c          [optional]
#
# It extracts the first mermaid block from each Markdown source, renders every
# source to SVG (failing on output-name collisions), then drops SVGs whose
# source has been removed.

set -euo pipefail

SOURCE_DIR="${SOURCE_DIR:-mermaid/source}"
OUTPUT_DIR="${OUTPUT_DIR:-mermaid/generated}"
CONFIG="${CONFIG:-}"

# mmdc isn't on PATH in the base image, and the -p puppeteer config that the
# base ENTRYPOINT normally supplies is lost now that we override it — so name
# both explicitly.
MMDC=/home/mermaidcli/node_modules/.bin/mmdc
PUPPETEER_CONFIG=/puppeteer-config.json
SCRIPTS=/action/src

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mmdc() { "$MMDC" -p "$PUPPETEER_CONFIG" "$@"; }

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Source directory '$SOURCE_DIR' does not exist; nothing to render."
  exit 0
fi

list_sources() {
  find "$SOURCE_DIR" \( -name '*.mmd' -o -name '*.mermaid' -o -name '*.md' \) | sort
}

# Extract the first mermaid block from each Markdown source into TEMP_DIR. No
# Chromium involved — just the extractor.
extract() {
  list_sources | while IFS= read -r src; do
    case "$src" in *.md) ;; *) continue ;; esac
    rel="${src#"$SOURCE_DIR"/}"
    tmp="$TEMP_DIR/${rel%.md}.mmd"
    mkdir -p "$(dirname "$tmp")"
    node "$SCRIPTS/extract-mermaid.mjs" "$src" "$tmp"
  done
}

# Fail if two sources would produce the same .svg. No associative arrays, so
# this stays portable to the older Bash that ships on macOS.
check_collisions() {
  local map; map="$(mktemp)"
  list_sources | while IFS= read -r src; do
    rel="${src#"$SOURCE_DIR"/}"
    printf '%s\t%s\n' "$OUTPUT_DIR/${rel%.*}.svg" "$src"
  done > "$map"

  local dupes; dupes="$(cut -f1 "$map" | sort | uniq -d || true)"
  if [ -n "$dupes" ]; then
    echo "Error: output collision — rename one source so each produces a unique .svg:" >&2
    while IFS= read -r out; do
      echo "  $out <-" >&2
      awk -F'\t' -v o="$out" '$1==o { print "    " $2 }' "$map" >&2
    done <<< "$dupes"
    rm -f "$map"
    exit 1
  fi
  rm -f "$map"
}

# Render every source (Markdown via its extracted TEMP_DIR file) to SVG, then
# drop SVGs whose source is gone. This is where Chromium runs.
convert() {
  check_collisions
  mkdir -p "$OUTPUT_DIR"

  list_sources | while IFS= read -r src; do
    rel="${src#"$SOURCE_DIR"/}"
    out="$OUTPUT_DIR/${rel%.*}.svg"
    case "$src" in
      *.md)
        input="$TEMP_DIR/${rel%.md}.mmd"
        if [ ! -s "$input" ]; then
          echo "No extracted mermaid for $src; skipping"
          continue
        fi
        ;;
      *) input="$src" ;;
    esac
    mkdir -p "$(dirname "$out")"
    echo "Rendering $input -> $out"
    args=(-i "$input" -o "$out")
    [ -n "$CONFIG" ] && args=(-c "$CONFIG" "${args[@]}")
    mmdc "${args[@]}"
  done

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
}

extract
convert
echo "Done."
