// Extract the first fenced `mermaid` code block from a Markdown string.
//
// By design only the first block is converted: one diagram per page, one
// predictable image name. This understands the common CommonMark fence
// variants (backtick and tilde fences, indentation, info strings) so it is
// more robust than a line-oriented regex, and it has no dependencies.

// Match a fence opener: up to 3 spaces of indent, 3+ backticks or tildes, then
// an optional info string whose first word is the language.
function matchOpenFence(line) {
  const m = /^( {0,3})(`{3,}|~{3,})[ \t]*(\S*)/.exec(line);
  if (!m) return null;
  const fence = m[2];
  // A backtick info string may not contain backticks.
  if (fence[0] === "`" && m[3].includes("`")) return null;
  return { indent: m[1].length, char: fence[0], len: fence.length, lang: m[3] };
}

// A closing fence uses the same character, is at least as long as the opener,
// and carries no info string.
function matchCloseFence(line, char, minLen) {
  const m = /^( {0,3})([`~]{3,})[ \t]*$/.exec(line);
  if (!m) return null;
  return m[2][0] === char && m[2].length >= minLen;
}

// Remove up to `indent` leading spaces, matching CommonMark's handling of
// indented fenced blocks.
function stripIndent(line, indent) {
  let n = 0;
  while (n < indent && line[n] === " ") n++;
  return line.slice(n);
}

// Returns { block, count } where `block` is the content of the first mermaid
// block (or null if there is none) and `count` is how many mermaid blocks the
// document contains.
export function extractFirstMermaid(markdown) {
  const lines = markdown.split(/\r?\n/);
  let count = 0;
  let firstBlock = null;

  let i = 0;
  while (i < lines.length) {
    const open = matchOpenFence(lines[i]);
    if (!open) {
      i++;
      continue;
    }

    // Consume the whole fenced block (whatever its language) so its contents
    // are never mistaken for further fences.
    const content = [];
    let j = i + 1;
    let closed = false;
    for (; j < lines.length; j++) {
      if (matchCloseFence(lines[j], open.char, open.len)) {
        closed = true;
        break;
      }
      content.push(stripIndent(lines[j], open.indent));
    }

    if (open.lang.toLowerCase() === "mermaid") {
      count++;
      if (firstBlock === null) firstBlock = content.join("\n");
    }

    i = closed ? j + 1 : j;
  }

  return { block: firstBlock, count };
}
