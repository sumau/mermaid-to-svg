# mermaid-to-svg

Author [Mermaid](https://mermaid.js.org/) diagrams once and reference them as
images across any file in the repo.

## The problem

GitHub renders inline ` ```mermaid ` code fences, but only *within* a single
Markdown file. You can't point one diagram at multiple pages — there's no
`![](diagram.mmd)`. SVGs, on the other hand, are ordinary image files: you can
embed the same one from as many files as you like, and they render everywhere
(GitHub, docs sites, package registries, and so on).

## The approach

Keep Mermaid **sources** in one folder and render them to **SVGs** in another.
You render locally with a single command and commit both; CI re-renders and
verifies the committed SVGs are up to date.

```
mermaid/
├── source/       # you write these
└── generated/    # you render these (committed SVGs)
```

Then reference the generated SVG from anywhere:

```markdown
![](mermaid/generated/diagram.svg)
```

Folder structure under `source/` is mirrored under `generated/`, so
`source/examples/sequence.mmd` becomes `generated/examples/sequence.svg`.

## Supported source formats

| Extension  | Behaviour                                             |
| ---------- | ----------------------------------------------------- |
| `.mmd`     | Rendered directly.                                    |
| `.mermaid` | Rendered directly.                                    |
| `.md`      | The **first** ` ```mermaid ` block is extracted and rendered — one diagram per page, one predictable image name. Extra blocks are skipped, with a warning in the Actions log. |

## Rendering

The only local dependency is **Docker** — rendering runs inside a pinned
[`mermaid-cli`](https://github.com/mermaid-js/mermaid-cli) image, so there's no
Node, npm, Puppeteer, or Chromium to install.

```sh
make diagrams   # or: ./render.sh
```

`render.sh` also keeps things tidy:

- **Collision guard** — fails if two sources would produce the same SVG
  (e.g. `diagram.mmd` and `diagram.md`), so nothing is silently clobbered.
- **Orphan cleanup** — deletes generated SVGs whose source no longer exists.

Output is deterministic: the pinned image renders the same bytes every run, so
CI can reliably verify your commit.

## Workflow

1. On a **branch**, add or edit files in `mermaid/source/`.
2. Run `make diagrams` and commit the source and SVGs **together**.
3. Open a PR. CI re-renders and fails if the committed SVGs are out of date; the
   rich diff shows a before/after image for review. Merge.

## Why verify-in-CI?

CI here is read-only: it renders and checks the result is already committed,
rather than committing back. That keeps source and SVG in one atomic commit —
no bot commits, no pulling before your next push, no write permissions for CI.
The cost is that contributors need Docker installed. We take that trade because
one `make diagrams` is cheap, and reproducible commits are worth more than
saving contributors a Docker install.
