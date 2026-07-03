# mermaid-to-svg

Docker-based GitHub Action that renders Mermaid sources to SVGs. Usage lives in
the README.

## Layout

- `action.yml`, `Dockerfile` — the action. `action.yml` points at the
  prebuilt GHCR image (`:v1`), so `uses: ./` would pull the released image,
  not test local changes — the smoke test covers those.
- `src/` — all logic, baked into the image at `/action/src`. `main.mjs` is
  the container ENTRYPOINT (I/O and mmdc orchestration only); `plan.mjs`
  holds the pure path-mapping/collision/orphan decisions; keep new decision
  logic there so it stays unit-testable.
- `test/` — unit tests and the end-to-end smoke test.
- `examples/` — this repo's own diagrams, rendered by `render-examples.yml`.

## Conventions

- Path defaults (`mermaid/source`, `mermaid/generated`) live in `action.yml`
  and `src/main.mjs`; the examples override them explicitly.
- Generated SVGs are committed, and their diffs should stay visible in PRs —
  the rendered image diff is a review aid, don't collapse them.
  `render-examples.yml` runs on every branch for this reason.
- Keep README and doc prose short.
- The commit-back snippet exists in both the README and
  `render-examples.yml`; keep them in step if either changes. Moving
  commit-back into the action is a separate, undecided phase.

## Testing (run before pushing)

- `npm test` — extractor unit tests (or `./render.sh test` to run them in
  Docker).
- `./render.sh smoke` — end-to-end test of the image against a fixture tree:
  rendering, Markdown extraction, orphan cleanup, collision guard.
- `shellcheck render.sh test/smoke-test.sh` — CI lints these.

## Releases

Run the **Release** workflow from the Actions tab with a semver like `1.0.0`.
It pushes the image to GHCR (`:1.0.0` and `:v1`), creates the `v1.0.0` tag and
GitHub Release, and force-moves the `v1` tag consumers pin. Don't move `v1` by
hand: `action.yml` at `v1` must match an image that exists on GHCR.
Marketplace listing, if wanted, is a manual step on the Release page.
