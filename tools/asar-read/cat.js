// Print one file inside the ASAR (ASAR-aware).
// Usage: node cat.js <file> [maxChars]
const fs = require('node:fs');
const file = process.argv[2];
// 限额按字符计（不是字节）：text.length 与 slice 都以字符为单位，两者一致。
const maxChars = Number(process.argv[3] || 200000);
let text;
try { text = fs.readFileSync(file, 'utf8'); }
catch (e) { console.log('READ_ERROR ' + e.message); process.exit(0); }
if (text.length > maxChars) {
  console.log(text.slice(0, maxChars));
  console.log(`...truncated (file has ${text.length} chars)`);
} else {
  console.log(text);
}
