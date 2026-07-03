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

Keep Mermaid **sources** in one folder and let a GitHub Action render them to
**SVGs** in another, committing the results back to the branch:

```
mermaid/
├── source/       # you write these
└── generated/    # the Action writes these (rendered SVGs)
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

## Workflow

1. On a **branch**, add or edit files in `mermaid/source/`.
2. Push. The [`convert-mermaid`](.github/workflows/convert-mermaid.yml) Action
   renders each source and commits the SVGs to `mermaid/generated/` on the same
   branch.
3. Review the committed SVGs (GitHub's rich diff shows a before/after image),
   then open a PR and merge to the default branch.

The Action also keeps things tidy:

- **Orphan cleanup** — deletes generated SVGs whose source no longer exists.
- **Collision guard** — fails the run if two sources would produce the same SVG
  (e.g. `diagram.mmd` and `diagram.md`), so nothing is silently clobbered.
- **Per-branch concurrency** — serializes runs on a branch so overlapping pushes
  don't collide on the commit-back.

> **Note:** because the Action commits back to your branch, pull after it runs
> before pushing again, or your next push will be rejected as non-fast-forward.

## Why commit-back?

Having CI commit the SVGs back is more awkward than the alternative (render
locally, let CI just check they're up to date) — it means bot commits and
pulling before your next push. We accept that for one reason: **zero local
tooling.** Rendering Mermaid needs `mermaid-cli` and headless Chromium; keeping
that on the runner means you push plain text and get an SVG back, with nothing
installed. Anyone who can edit a file in GitHub's web UI can add a diagram.
