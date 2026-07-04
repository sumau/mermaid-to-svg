#!/usr/bin/env bash
#
# Local preview of what the action produces in CI: converts
# examples/mermaid/source -> examples/mermaid/generated with the same pinned
# mermaid-cli the action installs. Node is the only dependency.
#
#   ./convert.sh          convert the examples
#   ./convert.sh smoke    run the end-to-end smoke test against a fixture tree

set -euo pipefail
cd "$(dirname "$0")"

npm ci

case "${1:-convert}" in
  smoke)
    ./test/smoke-test.sh
    ;;
  convert)
    SOURCE_DIR=examples/mermaid/source \
    OUTPUT_DIR=examples/mermaid/generated \
    CONFIG=examples/mermaid/config.json \
      node src/main.mjs
    ;;
  *) echo "usage: $0 [convert|smoke]" >&2; exit 2 ;;
esac

echo "Done."
