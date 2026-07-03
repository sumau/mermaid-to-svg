#!/usr/bin/env bash
#
# Render every Mermaid source under mermaid/source/ to an SVG under
# mermaid/generated/, using the pinned mermaid-cli Docker image.
#
# Subcommands, so CI can run them as separate steps and a failure points at the
# phase that broke:
#   ./render.sh test      # run the Markdown-extractor unit tests
#   ./render.sh extract   # Markdown -> mermaid text in .mermaid-tmp/
#   ./render.sh convert   # mermaid  -> SVG (collision guard + orphan cleanup)
# Run with no argument (./render.sh) to extract + convert — e.g. locally to
# preview what CI will produce. Docker is the only dependency.

set -euo pipefail

# Folder layout and pinned image live in one place, shared with the workflow.
# shellcheck source=render.config
source "$(dirname "$0")/render.config"

# Run mmdc inside the image, repo mounted at /data (the image's workdir).
# -u keeps generated files owned by the host user, not root.
mmdc_in_image() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD":/data "$IMAGE" "$@"
}

# Run the bundled Node (for Markdown extraction) inside the same image.
node_in_image() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD":/data --entrypoint node "$IMAGE" "$@"
}

list_sources() {
  find "$SOURCE_DIR" \( -name '*.mmd' -o -name '*.mermaid' -o -name '*.md' \) | sort
}

# Run the Markdown-extractor unit tests using the image's Node.
run_tests() {
  node_in_image --test scripts/extract-mermaid.test.mjs
}

# Phase 1: extract the first mermaid block from each Markdown source into
# TEMP_DIR. No Chromium involved — just the extractor.
extract() {
  rm -rf "$TEMP_DIR"
  list_sources | while IFS= read -r src; do
    case "$src" in *.md) ;; *) continue ;; esac
    rel="${src#"$SOURCE_DIR"/}"
    tmp="$TEMP_DIR/${rel%.md}.mmd"
    mkdir -p "$(dirname "$tmp")"
    node_in_image scripts/extract-mermaid.mjs "$src" "$tmp"
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

# Phase 2: render every source (Markdown via its extracted .mermaid-tmp file) to
# SVG, then drop SVGs whose source is gone. This is where Chromium runs.
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
    # No -p: the pinned image ships its own /puppeteer-config.json (system
    # Chromium + --no-sandbox) and passes it by default.
    mmdc_in_image -c "$CONFIG" -i "$input" -o "$out"
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

  rm -rf "$TEMP_DIR"
}

case "${1:-all}" in
  test)    run_tests ;;
  extract) extract ;;
  convert) convert ;;
  all)     extract; convert ;;
  *) echo "usage: $0 [test|extract|convert]" >&2; exit 2 ;;
esac

echo "Done."
