#!/usr/bin/env bash
#
# Local preview of what the action produces in CI. Builds this repo's action
# image and runs it against examples/mermaid/, so the output matches CI.
# Docker is the only dependency.
#
#   ./render.sh          build the image and render examples/mermaid/source -> examples/mermaid/generated
#   ./render.sh test     run the Markdown-extractor unit tests (in Docker; or just `npm test`)
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
    # Tests aren't baked into the image; mount the repo and run them there.
    docker run --rm --entrypoint node -v "$PWD":/work -w /work \
      "$IMAGE_TAG" --test test/extract-mermaid.test.mjs
    ;;
  smoke)
    ./test/smoke-test.sh "$IMAGE_TAG"
    ;;
  render)
    docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
      -v "$PWD":/github/workspace -w /github/workspace \
      -e SOURCE_DIR=examples/mermaid/source \
      -e OUTPUT_DIR=examples/mermaid/generated \
      -e CONFIG=examples/mermaid/config.json \
      "$IMAGE_TAG"
    ;;
  *) echo "usage: $0 [render|test|smoke]" >&2; exit 2 ;;
esac

echo "Done."
