// List one directory inside the ASAR (ASAR-aware). Usage: node ls.js <dir> [limit]
const fs = require('node:fs');
const dir = process.argv[2];
const limit = Number(process.argv[3] || 200);
const entries = fs.readdirSync(dir, { withFileTypes: true });
let n = 0;
for (const e of entries) {
  if (n++ >= limit) { console.log('...truncated'); break; }
  let size = '';
  try { size = e.isDirectory() ? '<dir>' : String(fs.statSync(dir + '/' + e.name).size); } catch { size = '?'; }
  console.log(`${e.isDirectory() ? 'D' : 'F'} ${String(size).padStart(10)} ${e.name}`);
}
console.log(`total=${entries.length}`);
