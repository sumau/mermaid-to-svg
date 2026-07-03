// Action entrypoint: render every Mermaid source under $SOURCE_DIR to an SVG
// under $OUTPUT_DIR, using the mermaid-cli tooling baked into this image. Runs
// inside the container with the consumer's repo mounted at the working
// directory. Configured via env (set from the action's inputs):
//
//   SOURCE_DIR  Mermaid sources (.mmd, .mermaid, .md)   [default mermaid/source]
//   OUTPUT_DIR  where SVGs are written                  [default mermaid/generated]
//   CONFIG      Mermaid config JSON for mmdc -c          [optional]
//
// It extracts the first mermaid block from each Markdown source, renders every
// source to SVG (failing on output-name collisions), then drops SVGs whose
// source has been removed. All decisions live in plan.mjs; this file is the
// I/O around them.

import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  rmdirSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { extractFirstMermaid } from "./extract-mermaid.mjs";
import { findCollisions, findOrphans, isSource, outputPathFor } from "./plan.mjs";

const SOURCE_DIR = process.env.SOURCE_DIR || "mermaid/source";
const OUTPUT_DIR = process.env.OUTPUT_DIR || "mermaid/generated";
const CONFIG = process.env.CONFIG || "";

// mmdc isn't on PATH in the base image, and the -p puppeteer config that the
// base ENTRYPOINT normally supplies is lost now that we override it — so name
// both explicitly.
const MMDC = process.env.MMDC || "/home/mermaidcli/node_modules/.bin/mmdc";
const PUPPETEER_CONFIG = process.env.PUPPETEER_CONFIG || "/puppeteer-config.json";

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

function mmdc(input, output) {
  const args = ["-p", PUPPETEER_CONFIG, "-i", input, "-o", output];
  if (CONFIG) args.unshift("-c", CONFIG);
  const result = spawnSync(MMDC, args, { stdio: "inherit" });
  if (result.error) {
    console.error(`Failed to run mmdc: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) process.exit(result.status ?? 1);
}

if (!existsSync(SOURCE_DIR)) {
  console.log(`Source directory '${SOURCE_DIR}' does not exist; nothing to render.`);
  process.exit(0);
}

const sources = listFiles(SOURCE_DIR).filter(isSource);

const collisions = findCollisions(sources);
if (collisions.length > 0) {
  console.error("Error: output collision — rename one source so each produces a unique .svg:");
  for (const { output, sources: culprits } of collisions) {
    console.error(`  ${join(OUTPUT_DIR, output)} <-`);
    for (const src of culprits) console.error(`    ${join(SOURCE_DIR, src)}`);
  }
  process.exit(1);
}

// Markdown sources render via a temp .mmd holding their first mermaid block.
const tempDir = mkdtempSync(join(tmpdir(), "mermaid-to-svg-"));
try {
  for (const rel of sources) {
    const srcPath = join(SOURCE_DIR, rel);
    let input = srcPath;

    if (rel.endsWith(".md")) {
      const { block, count } = extractFirstMermaid(readFileSync(srcPath, "utf8"));
      if (count > 1) {
        console.log(`::warning file=${srcPath}::Found ${count} mermaid blocks; only the first is rendered.`);
      }
      if (block === null || block.trim() === "") {
        console.log(`No mermaid block found in ${srcPath}; skipping`);
        continue;
      }
      input = join(tempDir, rel.replace(/\.md$/, ".mmd"));
      mkdirSync(dirname(input), { recursive: true });
      writeFileSync(input, block.endsWith("\n") ? block : `${block}\n`);
    }

    const output = join(OUTPUT_DIR, outputPathFor(rel));
    mkdirSync(dirname(output), { recursive: true });
    console.log(`Rendering ${input} -> ${output}`);
    mmdc(input, output);
  }
} finally {
  rmSync(tempDir, { recursive: true, force: true });
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
