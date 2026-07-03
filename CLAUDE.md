# mermaid-to-svg

Docker-based GitHub Action that renders Mermaid sources to SVGs. Usage lives in
the README; the rendering logic lives in `entrypoint.sh` (bash, runs in the
mermaid-cli image) and `scripts/extract-mermaid.mjs`.

## Conventions

- Path defaults (`mermaid/source`, `mermaid/generated`) are defined in
  `action.yml` and `entrypoint.sh`; callers rely on the defaults rather than
  repeating the paths.
- Generated SVGs are committed, and their diffs should stay visible in PRs —
  the rendered image diff is a review aid, don't collapse them.
- Keep README and doc prose short.
- The commit-back snippet exists in both the README and the workflow; keep them
  in step if either changes. Moving commit-back into the action is a separate,
  undecided phase.

## Testing (run before pushing)

- `node --test scripts/*.test.mjs` — extractor unit tests (or
  `./render.sh test` to run them in Docker).
- `./render.sh smoke` — end-to-end test of the image against a fixture tree:
  rendering, Markdown extraction, orphan cleanup, collision guard.

## Releases

Consumers pin `sumau/mermaid-to-svg@v1`. After merging a release-worthy change
to main, move the tag:

```sh
git tag -f -a v1 -m "v1" && git push -f origin v1
```
