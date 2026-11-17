// 用真实 DSH 技能注册表 + 真实 skill-filesystem 提供器，列出某个配置下模型能看到的技能目录。
//
// 这是能力级隔离的产物级验证：直接驱动 DSH 的 skill registry 与 filesystem provider，
// 用 legavis 模式声明里的那一组 skill-filesystem 配置，取出「模型技能目录」。
// 不启动会话、不连模型、不断言实现细节——只断言技能目录的内容。
//
// 运行（Electron 的 ASAR 感知 fs 才能读到 DSH 安装目录）：
//   pwsh -File tools/asar-read/asar-node.ps1 tools/legavis-skills/verify-legavis-catalog.cjs [viewDir]
//
// 参数：
//   argv[2] 白名单视图目录（默认 $DSH_HOME\legavis-skills）
//   argv[3] 'legavis' 走 legavis 配置；'standard' 走出厂 standard 配置（含默认发现根）作对照

const path = require('node:path')
const os = require('node:os')

const ASAR_MODULES = 'D:\\programs\\dsh\\resources\\app.asar\\dsh\\node_modules\\@deepseek-ai'

const { Context } = require(path.join(ASAR_MODULES, 'cordis', 'lib', 'index.js'))
const skillPlugin = require(path.join(ASAR_MODULES, 'dsh-skill', 'lib', 'index.js'))
const filesystemPlugin = require(path.join(ASAR_MODULES, 'dsh-skill-filesystem', 'lib', 'index.js'))

const profile = process.argv[2] === 'standard' ? 'standard' : 'legavis'
const dshHome = (process.env.DSH_HOME || path.join(os.homedir(), '.dsh')).trim()
const viewDir = process.argv[3] || path.join(dshHome, 'legavis-skills')

async function main() {
  const ctx = new Context()
  await ctx.plugin(skillPlugin.SkillRegistry)
  const config = profile === 'standard'
    ? {}
    : {
        includeDefaultRoots: false,
        watchFollowSymlinks: true,
        customSkillDirs: [viewDir],
      }
  await ctx.plugin(filesystemPlugin, config)

  const skills = await ctx.skills.list()
  const names = skills.map(skill => skill.name).sort()

  // 负向：白名单外的技能在 legavis 模式下既不出现，也加载不到。
  const outside = ['arkcli-usage', 'arkcli-gen', 'gtd-triage', 'obsidian-annotations', 'writing-shape']
  const inCatalog = outside.filter(name => names.includes(name))
  const loadable = []
  for (const name of outside) {
    const definition = await ctx.skills.get(name)
    if (definition !== undefined) loadable.push(name)
  }

  // 已知行为（非失败断言）：能力级隔离不是路径级隔离，白名单外的技能文件仍在磁盘上，
  // 带 read/pwsh 的 agent 直接按路径仍读得到。防线是案件项目 AGENTS.md 的纪律条款。
  const fs = require('node:fs')
  const agentsHome = (process.env.DSH_AGENTS_HOME || path.join(os.homedir(), '.agents')).trim()
  const outsidePath = path.join(agentsHome, 'skills', 'arkcli-usage', 'SKILL.md')
  const pathReadable = fs.existsSync(outsidePath)

  console.log(JSON.stringify({
    profile,
    viewDir,
    count: names.length,
    names,
    negative: {
      checked: outside,
      presentInCatalog: inCatalog,
      loadableViaSkillTool: loadable,
    },
    knownBehaviour: {
      note: '能力级隔离不是路径级隔离：白名单外技能文件仍在磁盘上，按路径直读仍可读。',
      pathStillReadable: pathReadable,
      path: outsidePath,
    },
  }, null, 2))

  await ctx.fiber.dispose()
}

main().catch((error) => {
  console.error('VERIFY_FAILED ' + (error && error.stack ? error.stack : String(error)))
  process.exitCode = 1
})
