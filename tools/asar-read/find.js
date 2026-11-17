// Bounded literal search inside one file (ASAR-aware).
// Usage: node find.js <file> <term> [maxMatches] [maxLineLen]
const fs = require('node:fs');
const file = process.argv[2];
const term = process.argv[3];
const maxMatches = Number(process.argv[4] || 40);
const maxLineLen = Number(process.argv[5] || 240);

let text;
try { text = fs.readFileSync(file, 'utf8'); }
catch (e) { console.log('READ_ERROR ' + e.message); process.exit(0); }
const lines = text.split(/\r?\n/);
const needle = term.toLowerCase();
let n = 0;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].toLowerCase().includes(needle)) {
    if (n++ >= maxMatches) { console.log(`...more matches truncated (${lines.length} lines total)`); break; }
    const l = lines[i].length > maxLineLen ? lines[i].slice(0, maxLineLen) + '…' : lines[i];
    console.log(`${i + 1}: ${l}`);
  }
}
console.log(`lines=${lines.length} matches=${n}`);
