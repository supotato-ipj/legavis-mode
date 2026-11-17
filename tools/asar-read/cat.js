// Print one file inside the ASAR (ASAR-aware).
// Usage: node cat.js <file> [maxBytes]
const fs = require('node:fs');
const file = process.argv[2];
const maxBytes = Number(process.argv[3] || 200000);
let text;
try { text = fs.readFileSync(file, 'utf8'); }
catch (e) { console.log('READ_ERROR ' + e.message); process.exit(0); }
if (text.length > maxBytes) {
  console.log(text.slice(0, maxBytes));
  console.log(`...truncated (file has ${text.length} chars)`);
} else {
  console.log(text);
}
