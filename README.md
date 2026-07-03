# mermaid-to-svg

A GitHub Action that renders [Mermaid](https://mermaid.js.org/) diagram sources
to SVGs — so you can author a diagram once and embed it as an image across any
file in your repo.

## The problem

GitHub renders inline ` ```mermaid ` code fences, but only *within* a single
Markdown file. You can't point one diagram at multiple pages — there's no
`![](diagram.mmd)`. SVGs, on the other hand, are ordinary image files: you can
embed the same one from as many files as you like, and they render everywhere
(GitHub, docs sites, package registries, and so on).

## Usage

Keep Mermaid **sources** in one folder; the action renders them to **SVGs** in
another, mirroring the folder structure (`source/examples/seq.mmd` →
`generated/examples/seq.svg`).

```yaml
name: Render Mermaid
on:
  push:
    paths: ["mermaid/**"]
permissions:
  contents: write          # so the commit-back step can push
jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sumau/mermaid-to-svg@v1

      # The action only renders; commit the results back yourself.
      - name: Commit generated SVGs
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add -A mermaid/generated
          git diff --cached --quiet || {
            git commit -m "Synchronize generated Mermaid diagrams"
            git push
          }
```

Then reference the generated SVG from anywhere:

```markdown
![](mermaid/generated/diagram.svg)
```

## Inputs

| Input        | Default             | Description                                            |
| ------------ | ------------------- | ------------------------------------------------------ |
| `source-dir` | `mermaid/source`    | Directory containing Mermaid sources.                  |
| `output-dir` | `mermaid/generated` | Directory the SVGs are written to (mirrors sources).   |
| `config`     | *(none)*            | Optional path to a Mermaid config JSON (`mmdc -c`).    |

## Supported source formats

| Extension  | Behaviour                                             |
| ---------- | ----------------------------------------------------- |
| `.mmd`     | Rendered directly.                                    |
| `.mermaid` | Rendered directly.                                    |
| `.md`      | The **first** ` ```mermaid ` block is extracted and rendered — one diagram per page, one predictable image name. Extra blocks are skipped, with a warning in the Actions log. |

## What it handles

- **Orphan cleanup** — deletes generated SVGs whose source no longer exists.
- **Collision guard** — fails the run if two sources would produce the same SVG
  (e.g. `diagram.mmd` and `diagram.md`), so nothing is silently clobbered.

> **Note:** the example above commits SVGs back to your branch, so pull after
> the Action runs before pushing again, or your next push will be rejected as
> non-fast-forward.

## Previewing locally (optional)

Run `./render.sh` to render `mermaid/source` → `mermaid/generated` exactly as CI
does. It builds this action's image and runs it, so the only dependency is
Docker and the output matches CI. `./render.sh test` runs the extractor's unit
tests; `./render.sh smoke` runs an end-to-end test of the image.
