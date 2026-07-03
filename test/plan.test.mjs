import { test } from "node:test";
import assert from "node:assert/strict";
import { findCollisions, findOrphans, isSource, outputPathFor } from "../src/plan.mjs";

test("isSource accepts the three source extensions and rejects the rest", () => {
  assert.equal(isSource("a.mmd"), true);
  assert.equal(isSource("a.mermaid"), true);
  assert.equal(isSource("nested/a.md"), true);
  assert.equal(isSource("a.svg"), false);
  assert.equal(isSource("a.markdown"), false);
  assert.equal(isSource("mmd"), false);
});

test("outputPathFor replaces the extension with .svg", () => {
  assert.equal(outputPathFor("diagram.mmd"), "diagram.svg");
  assert.equal(outputPathFor("page.md"), "page.svg");
  assert.equal(outputPathFor("flow.mermaid"), "flow.svg");
});

test("outputPathFor mirrors nested paths", () => {
  assert.equal(outputPathFor("examples/seq.mmd"), "examples/seq.svg");
});

test("outputPathFor strips only the final extension", () => {
  assert.equal(outputPathFor("v1.2/diagram.mmd"), "v1.2/diagram.svg");
  assert.equal(outputPathFor("release.notes.md"), "release.notes.svg");
});

test("findCollisions is empty for distinct outputs", () => {
  assert.deepEqual(findCollisions(["a.mmd", "b.md", "nested/a.mmd"]), []);
});

test("findCollisions detects cross-extension collisions", () => {
  assert.deepEqual(findCollisions(["diagram.mmd", "diagram.md", "other.mmd"]), [
    { output: "diagram.svg", sources: ["diagram.md", "diagram.mmd"] },
  ]);
});

test("findCollisions reports three-way collisions and sorts output", () => {
  const collisions = findCollisions(["b.md", "a.mermaid", "a.mmd", "a.md", "b.mmd"]);
  assert.deepEqual(collisions, [
    { output: "a.svg", sources: ["a.md", "a.mermaid", "a.mmd"] },
    { output: "b.svg", sources: ["b.md", "b.mmd"] },
  ]);
});

test("findCollisions keeps same-named sources in different dirs apart", () => {
  assert.deepEqual(findCollisions(["a.mmd", "nested/a.md"]), []);
});

test("findOrphans returns SVGs with no surviving source", () => {
  const orphans = findOrphans(["kept.svg", "gone.svg"], ["kept.mmd"]);
  assert.deepEqual(orphans, ["gone.svg"]);
});

test("findOrphans matches sources of any extension", () => {
  const orphans = findOrphans(["a.svg", "b.svg", "c.svg"], ["a.mmd", "b.md"]);
  assert.deepEqual(orphans, ["c.svg"]);
});

test("findOrphans handles nested paths", () => {
  const orphans = findOrphans(["nested/a.svg", "nested/b.svg"], ["nested/a.mermaid"]);
  assert.deepEqual(orphans, ["nested/b.svg"]);
});

test("findOrphans is empty when every SVG has a source", () => {
  assert.deepEqual(findOrphans(["a.svg"], ["a.mmd", "unrendered.md"]), []);
});
