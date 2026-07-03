#!/usr/bin/env bash
#
# Local preview of what the action produces in CI. Builds this repo's action
# image and runs it against mermaid/, so the output matches CI. Docker is the
# only dependency.
#
#   ./render.sh          build the image and render mermaid/source -> mermaid/generated
#   ./render.sh test     run the Markdown-extractor unit tests
#   ./render.sh smoke    run the end-to-end smoke test against a fixture tree
#
# Unlike CI (which runs the action as root), this runs the container as your
# host user so generated files stay owned by you, not root.

set -euo pipefail
cd "$(dirname "$0")"

IMAGE_TAG="mermaid-to-svg:local"

docker build -t "$IMAGE_TAG" .

case "${1:-render}" in
  test)
    docker run --rm --entrypoint node "$IMAGE_TAG" \
      --test /action/scripts/extract-mermaid.test.mjs
    ;;
  smoke)
    ./scripts/smoke-test.sh "$IMAGE_TAG"
    ;;
  render)
    # SOURCE_DIR and OUTPUT_DIR are left to the entrypoint's defaults.
    docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
      -v "$PWD":/github/workspace -w /github/workspace \
      -e CONFIG=mermaid/config.json \
      "$IMAGE_TAG"
    ;;
  *) echo "usage: $0 [render|test|smoke]" >&2; exit 2 ;;
esac

echo "Done."
