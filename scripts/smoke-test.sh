#!/usr/bin/env bash
#
# End-to-end test of the action image against a fixture workspace: renders
# .mmd/.mermaid/.md sources (mirroring nested paths), removes orphaned SVGs,
# and fails on output collisions. Run via `./render.sh smoke`, which builds
# the image and passes its tag here.

set -euo pipefail

IMAGE_TAG="${1:?usage: smoke-test.sh <image-tag>}"

WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$WORKSPACE"' EXIT

run_action() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$WORKSPACE":/github/workspace -w /github/workspace "$IMAGE_TAG"
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# Happy path: direct render, nested path mirroring, Markdown extraction, and
# cleanup of an SVG whose source no longer exists.
mkdir -p "$WORKSPACE/mermaid/source/nested" "$WORKSPACE/mermaid/generated"
printf 'graph LR\n  A --> B\n' > "$WORKSPACE/mermaid/source/plain.mmd"
printf 'graph TD\n  C --> D\n' > "$WORKSPACE/mermaid/source/nested/deep.mermaid"
printf '# Doc\n\n```mermaid\ngraph LR\n  E --> F\n```\n' > "$WORKSPACE/mermaid/source/page.md"
printf '<svg></svg>\n' > "$WORKSPACE/mermaid/generated/orphan.svg"

run_action

[ -s "$WORKSPACE/mermaid/generated/plain.svg" ] || fail "plain.mmd was not rendered"
[ -s "$WORKSPACE/mermaid/generated/nested/deep.svg" ] || fail "nested/deep.mermaid was not rendered to a mirrored path"
[ -s "$WORKSPACE/mermaid/generated/page.svg" ] || fail "mermaid block was not extracted and rendered from page.md"
[ ! -e "$WORKSPACE/mermaid/generated/orphan.svg" ] || fail "orphaned SVG was not removed"

# Collision guard: two sources mapping to the same .svg must fail the run.
printf '# Doc\n\n```mermaid\ngraph LR\n  G --> H\n```\n' > "$WORKSPACE/mermaid/source/plain.md"
if run_action; then
  fail "collision between plain.mmd and plain.md was not detected"
fi

echo "Smoke test passed."
