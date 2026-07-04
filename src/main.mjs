// Action entrypoint: convert every Mermaid source under $SOURCE_DIR to an SVG
// under $OUTPUT_DIR, using the mermaid-cli Node API. Runs with the consumer's
// repo as the working directory. Configured via env (set from the action's
// inputs):
//
//   SOURCE_DIR  Mermaid sources (.mmd, .mermaid, .md)   [default mermaid/source]
//   OUTPUT_DIR  where SVGs are written                  [default mermaid/generated]
//   CONFIG      Mermaid config JSON                      [optional]
//
// It extracts the first mermaid block from each Markdown source, converts every
// source to SVG (failing on output-name collisions), then drops SVGs whose
// source has been removed. All decisions live in plan.mjs; this file is the
// I/O around them.

import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  rmdirSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative } from "node:path";
import { renderMermaid } from "@mermaid-js/mermaid-cli";
import puppeteer from "puppeteer";
import { extractFirstMermaid } from "./extract-mermaid.mjs";
import { findCollisions, findOrphans, isSource, outputPathFor } from "./plan.mjs";

const SOURCE_DIR = process.env.SOURCE_DIR || "mermaid/source";
const OUTPUT_DIR = process.env.OUTPUT_DIR || "mermaid/generated";
const CONFIG = process.env.CONFIG || "";

// Relative paths of all files under root, sorted.
function listFiles(root) {
  const files = [];
  (function recur(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) recur(path);
      else files.push(relative(root, path));
    }
  })(root);
  return files.sort();
}

function removeEmptyDirs(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) removeEmptyDirs(join(dir, entry.name));
  }
  if (readdirSync(dir).length === 0) rmdirSync(dir);
}

if (!existsSync(SOURCE_DIR)) {
  console.log(`Source directory '${SOURCE_DIR}' does not exist; nothing to convert.`);
  process.exit(0);
}

const sources = listFiles(SOURCE_DIR).filter(isSource);

const collisions = findCollisions(sources);
if (collisions.length > 0) {
  console.error("Error: output collision — rename one source so each produces a unique .svg:");
  for (const { output, sources: culprits } of collisions) {
    console.error(`  ${join(OUTPUT_DIR, output)} <-`);
    for (const src of culprits) console.error(`    ${join(SOURCE_DIR, src)}`);
    for (const src of culprits) {
      console.log(`::error file=${join(SOURCE_DIR, src)}::Collides on ${join(OUTPUT_DIR, output)}; rename so each source produces a unique .svg.`);
    }
  }
  process.exit(1);
}

const mermaidConfig = CONFIG ? JSON.parse(readFileSync(CONFIG, "utf8")) : undefined;

// One browser serves every diagram; renderMermaid never closes a caller's browser.
// --no-sandbox: GitHub's Ubuntu 24 runners block Chrome's sandbox (AppArmor
// restricts unprivileged user namespaces); the old Docker action ran with the
// same flag via its puppeteer-config.json.
const browser = await puppeteer.launch({ args: ["--no-sandbox"] });
try {
  for (const rel of sources) {
    const srcPath = join(SOURCE_DIR, rel);
    let definition = readFileSync(srcPath, "utf8");

    if (rel.endsWith(".md")) {
      const { block, count } = extractFirstMermaid(definition);
      if (block === null || block.trim() === "") {
        console.log(`::warning file=${srcPath}::No mermaid block found in ${srcPath}; skipping.`);
        continue;
      }
      definition = block;
      console.log(`Extracted mermaid block from ${srcPath}`);
      if (count > 1) {
        console.log(`::warning file=${srcPath}::Found ${count} mermaid blocks; only the first was extracted.`);
      }
    }

    const output = join(OUTPUT_DIR, outputPathFor(rel));
    mkdirSync(dirname(output), { recursive: true });
    console.log(`Converting ${srcPath} -> ${output}`);
    try {
      const { data } = await renderMermaid(browser, definition, "svg", { mermaidConfig });
      writeFileSync(output, data);
    } catch (err) {
      console.error(err);
      const firstLine = String(err.message ?? err).split("\n")[0];
      console.log(`::error file=${srcPath}::Failed to convert ${srcPath}: ${firstLine}`);
      process.exit(1);
    }
  }
} finally {
  await browser.close();
}

if (existsSync(OUTPUT_DIR)) {
  const svgs = listFiles(OUTPUT_DIR).filter((f) => f.endsWith(".svg"));
  for (const orphan of findOrphans(svgs, sources)) {
    console.log(`Removing orphaned SVG: ${join(OUTPUT_DIR, orphan)}`);
    rmSync(join(OUTPUT_DIR, orphan));
  }
  removeEmptyDirs(OUTPUT_DIR);
}

console.log("Done.");
