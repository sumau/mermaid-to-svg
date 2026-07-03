# Multi-block example

This page has more than one mermaid block. By design only the first is rendered,
so the workflow should emit a warning for the second block below.

```mermaid
graph LR
    A[First block] --> B[Rendered to SVG]
```

Some explanatory text between the diagrams.

```mermaid
graph LR
    X[Second block] --> Y[Skipped, warning logged]
```
