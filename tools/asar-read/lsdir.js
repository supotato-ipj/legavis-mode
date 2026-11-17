// List one directory (names only) inside the ASAR.
const fs = require('node:fs');
const dir = process.argv[2];
const out = fs.readdirSync(dir).sort();
console.log(out.join('\n'));
console.log('total=' + out.length);
