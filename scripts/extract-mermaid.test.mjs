import { test } from "node:test";
import assert from "node:assert/strict";
import { extractFirstMermaid } from "./extract-mermaid.mjs";

test("extracts a single mermaid block", () => {
  const md = ["# Title", "", "```mermaid", "graph LR", "  A --> B", "```", ""].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 1);
  assert.equal(block, "graph LR\n  A --> B");
});

test("returns only the first block but counts all of them", () => {
  const md = [
    "```mermaid",
    "graph LR",
    "A --> B",
    "```",
    "text",
    "```mermaid",
    "graph LR",
    "X --> Y",
    "```",
  ].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 2);
  assert.equal(block, "graph LR\nA --> B");
});

test("ignores non-mermaid fenced blocks", () => {
  const md = ["```js", "const a = 1;", "```", "```mermaid", "graph LR", "A-->B", "```"].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 1);
  assert.equal(block, "graph LR\nA-->B");
});

test("does not treat fences inside another block as mermaid", () => {
  const md = ["```text", "```mermaid", "not real", "```", "```"].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 0);
  assert.equal(block, null);
});

test("supports tilde fences", () => {
  const md = ["~~~mermaid", "graph LR", "A --> B", "~~~"].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 1);
  assert.equal(block, "graph LR\nA --> B");
});

test("handles an info string with surrounding spaces", () => {
  const md = ["``` mermaid  ", "graph LR", "A --> B", "```"].join("\n");
  const { count } = extractFirstMermaid(md);
  assert.equal(count, 1);
});

test("strips the opening fence indentation from content", () => {
  const md = ["  ```mermaid", "  graph LR", "  A --> B", "  ```"].join("\n");
  const { block } = extractFirstMermaid(md);
  assert.equal(block, "graph LR\nA --> B");
});

test("captures an unclosed block that runs to end of file", () => {
  const md = ["```mermaid", "graph LR", "A --> B"].join("\n");
  const { block, count } = extractFirstMermaid(md);
  assert.equal(count, 1);
  assert.equal(block, "graph LR\nA --> B");
});

test("returns null when there is no mermaid block", () => {
  const { block, count } = extractFirstMermaid("# Just prose\n\nNo diagrams here.\n");
  assert.equal(count, 0);
  assert.equal(block, null);
});
