// Decompress a .zstd file (possibly many concatenated frames) and print matching lines.
// Usage: node zstd-cat.cjs <file.zstd> [maxMatches] [grepPattern]
const fs = require('node:fs')
const zlib = require('node:zlib')

const file = process.argv[2]
const maxMatches = Number(process.argv[3] || 20)
const pattern = process.argv[4]

async function main() {
  const stream = fs.createReadStream(file).pipe(zlib.createZstdDecompress())
  const chunks = []
  await new Promise((resolve, reject) => {
    stream.on('data', chunk => chunks.push(chunk))
    stream.on('end', resolve)
    stream.on('error', reject)
  })
  const text = Buffer.concat(chunks).toString('utf8')
  const lines = text.split(/\r?\n/)
  let shown = 0
  for (let i = 0; i < lines.length; i++) {
    if (pattern && !lines[i].includes(pattern)) continue
    console.log(`${i + 1}: ${lines[i].slice(0, 700)}`)
    if (++shown >= maxMatches) { console.log('...more matches'); break }
  }
  console.log(`lines=${lines.length} bytes=${text.length}`)
}

main().catch((error) => {
  console.log('DECOMPRESS_ERROR ' + (error && error.message))
})
