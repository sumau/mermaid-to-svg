// Pure decisions about which sources convert to which outputs. No filesystem
// access — everything operates on repo-relative paths so it can be unit
// tested directly.

export const SOURCE_EXTENSIONS = [".mmd", ".mermaid", ".md"];

export function isSource(relPath) {
  return SOURCE_EXTENSIONS.some((ext) => relPath.endsWith(ext));
}

// source/examples/seq.mmd -> source/examples/seq.svg. Only the final
// segment's extension is replaced, so dotted directory names are safe.
export function outputPathFor(relSource) {
  return relSource.replace(/\.[^/.]+$/, "") + ".svg";
}

// Sources that would produce the same .svg (e.g. diagram.mmd and diagram.md),
// as [{ output, sources }] sorted for stable error messages.
export function findCollisions(relSources) {
  const byOutput = new Map();
  for (const src of relSources) {
    const out = outputPathFor(src);
    if (!byOutput.has(out)) byOutput.set(out, []);
    byOutput.get(out).push(src);
  }
  return [...byOutput]
    .filter(([, sources]) => sources.length > 1)
    .map(([output, sources]) => ({ output, sources: [...sources].sort() }))
    .sort((a, b) => a.output.localeCompare(b.output));
}

// Generated SVGs whose source no longer exists.
export function findOrphans(relSvgs, relSources) {
  const expected = new Set(relSources.map(outputPathFor));
  return relSvgs.filter((svg) => !expected.has(svg));
}
