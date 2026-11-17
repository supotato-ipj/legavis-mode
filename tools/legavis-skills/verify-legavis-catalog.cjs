// 用真实 DSH 技能注册表 + 真实 skill-filesystem 提供器，列出某个配置下模型能看到的技能目录。
//
// 这是能力级隔离的产物级验证：直接驱动 DSH 的 skill registry 与 filesystem provider，
// 取技能目录。不启动会话、不连模型、不断言实现细节——只断言技能目录的内容。
//
// legavis 模式的 skill-filesystem 配置**从模式包声明里读**（bundles/dsh-legavis-mode/cordis.patch.yml），
// 不是在这里写死：YAML 用 DSH 安装目录里的 `yaml` 包解析，`!!js` 表达式按 Loader 的方式求值
// （new Function('ctx','expr','with (ctx) { return eval(expr) }')，见 docs/research/dsh-preset-research.md
// 与 cordis-plugin-loader 的 lib/types/config/utils.js），因此模式包里写的路径表达式真的被跑到。
//
// 运行（Electron 的 ASAR 感知 fs 才能读到 DSH 安装目录）：
//   pwsh -File tools/asar-read/asar-node.ps1 <本脚本绝对路径> [legavis|standard] [viewDir]
//
// 参数：
//   argv[2] 'legavis'（默认）走模式包声明的 skill-filesystem 行；
//           'standard' 走默认发现根作对照（不是出厂 standard 预设——出厂 standard 还会
//           额外注入 agent-preset 包自带的 skills 目录，见验收记录）
//   argv[3] 可选的视图目录覆盖（只对 legavis 模式有意义）。不给就用模式包声明里
//           `!!js` 表达式算出来的那个路径——默认路径正是走那条声明。

const path = require('node:path')
const os = require('node:os')
const fs = require('node:fs')
const { pathToFileURL } = require('node:url')

const ASAR_MODULES = 'D:\\programs\\dsh\\resources\\app.asar\\dsh\\node_modules\\@deepseek-ai'
const ASAR_NODE_MODULES = 'D:\\programs\\dsh\\resources\\app.asar\\dsh\\node_modules'

const { Context } = require(path.join(ASAR_MODULES, 'cordis', 'lib', 'index.js'))
const skillPlugin = require(path.join(ASAR_MODULES, 'dsh-skill', 'lib', 'index.js'))
const filesystemPlugin = require(path.join(ASAR_MODULES, 'dsh-skill-filesystem', 'lib', 'index.js'))

const mode = process.argv[2] === 'standard' ? 'standard' : 'legavis'
const viewDirOverride = process.argv[3] || ''
const REPO_ROOT = path.resolve(__dirname, '..', '..')
const BUNDLE_PATCH = path.join(REPO_ROOT, 'bundles', 'dsh-legavis-mode', 'cordis.patch.yml')

// Loader 的表达式求值方式：作用域是 fiber context，`with (ctx)` 让表达式能看到 ctx 上的属性。
// legavis 的路径表达式只用全局 `process`，standard 的用 ctx 上的 `baseUrl`；这里给一个最小的 ctx。
const evaluate = new Function('ctx', 'expr', 'with (ctx) { return eval(expr) }')

// Loader 的 interpolate：递归把 YAML `!!js` 节点换成求值结果。
function interpolate(ctx, value) {
  if (value !== null && typeof value === 'object' && '__jsExpr' in value) {
    return evaluate(ctx, value.__jsExpr)
  }
  if (Array.isArray(value)) return value.map(item => interpolate(ctx, item))
  if (value !== null && typeof value === 'object') {
    const out = {}
    for (const [key, item] of Object.entries(value)) out[key] = interpolate(ctx, item)
    return out
  }
  return value
}

// 载入 DSH 安装目录里的 `yaml` 包（ASAR 感知）。返回 null 表示拿不到。
function loadYaml() {
  const candidates = [
    path.join(ASAR_NODE_MODULES, 'yaml'),
    path.join(ASAR_MODULES, 'dsh-web-app', 'node_modules', 'yaml'),
  ]
  for (const candidate of candidates) {
    try {
      const mod = require(candidate)
      if (mod && typeof mod.parseDocument === 'function') return { mod, from: candidate }
    } catch {
      // 试下一个
    }
  }
  return null
}

// 解析模式包声明，取出 skill-filesystem 行的 config。
//
// 走的哪条路（本机实测：走的是第一条——YAML 包可用）：
//   1) 首选：用 DSH 安装目录里的 `yaml` 包解析（ASAR 感知，`require` 走 Electron 的 ASAR fs），
//      并用 Loader 的自定义标签 `tag:yaml.org,2002:js` 把 `!!js` 标量解成 `{ __jsExpr }`；
//      得到的 `configSource` 里会写明实际用的是哪个 yaml 包路径。
//   2) 兜底：万一 YAML 包这样加载不到，就从文件文本里窄范围地抽出 `customSkillDirs` 下方的
//      `!!js` 表达式与两个布尔开关（不做通用 YAML 解析）；`configSource` 里会标明是文本抽取兜底。
function readSkillFilesystemConfig() {
  const text = fs.readFileSync(BUNDLE_PATCH, 'utf8')
  const loader = loadYaml()
  if (loader) {
    const { mod, from } = loader
    const document = mod.parseDocument(text, {
      customTags: [{ tag: 'tag:yaml.org,2002:js', resolve: value => ({ __jsExpr: value }) }],
    })
    if (document.errors.length === 0) {
      const parsed = document.toJS()
      const rows = (parsed[0] && parsed[0].insert) || []
      for (const row of rows) {
        const plugins = (row.config && row.config.plugins) || []
        for (const plugin of plugins) {
          if (plugin.id === 'skill-filesystem' && plugin.config) {
            return { config: plugin.config, source: `YAML 包（${from}）+ Loader 的 !!js 求值` }
          }
        }
      }
      throw new Error(`模式包声明里没有 skill-filesystem 行：${BUNDLE_PATCH}`)
    }
  }

  // 窄范围文本抽取：只认 customSkillDirs 下方的 !!js 表达式与两个布尔开关。
  const expression = /customSkillDirs:\s*\r?\n\s*-\s*!!js\s+(.+)/.exec(text)
  if (!expression) throw new Error(`无法从模式包声明里取出 customSkillDirs 的 !!js 表达式：${BUNDLE_PATCH}`)
  const flag = name => {
    const matched = new RegExp(`${name}:\\s*(true|false)`).exec(text)
    return matched ? matched[1] === 'true' : undefined
  }
  return {
    config: {
      includeDefaultRoots: flag('includeDefaultRoots'),
      watchFollowSymlinks: flag('watchFollowSymlinks'),
      customSkillDirs: [{ __jsExpr: expression[1].trim() }],
    },
    source: '文本抽取（YAML 包不可用时的兜底）',
  }
}

async function main() {
  const ctx = new Context()
  await ctx.plugin(skillPlugin.SkillRegistry)

  let config = {}
  let configSource = '默认发现根'
  if (mode === 'legavis') {
    const declared = readSkillFilesystemConfig()
    const loaderCtx = { baseUrl: pathToFileURL(BUNDLE_PATCH).href }
    config = interpolate(loaderCtx, declared.config)
    configSource = `模式包声明 ${path.basename(BUNDLE_PATCH)} → ${declared.source}`
    if (viewDirOverride) {
      config.customSkillDirs = [viewDirOverride]
      configSource += `（视图目录被命令行覆盖为 ${viewDirOverride}）`
    }
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
  const agentsHome = (process.env.DSH_AGENTS_HOME || path.join(os.homedir(), '.agents')).trim()
  const outsidePath = path.join(agentsHome, 'skills', 'arkcli-usage', 'SKILL.md')
  const pathReadable = fs.existsSync(outsidePath)

  console.log(JSON.stringify({
    mode,
    configSource,
    customSkillDirs: config.customSkillDirs,
    count: names.length,
    names,
    negative: {
      checked: outside,
      presentInCatalog: inCatalog,
      loadableViaSkillTool: loadable,
    },
    deliberatelyAbsent: {
      name: 'dsh-doc',
      presentInCatalog: names.includes('dsh-doc'),
      note: mode === 'legavis'
        ? 'legavis 只把 customSkillDirs 指向白名单视图目录，故意不注入 agent-preset 包自带的 skills 目录，所以看不到 dsh-doc。'
        : '本模式是「默认发现根」对照，不是出厂 standard 预设。出厂 standard 还额外注入 agent-preset 包自带的 skills 目录，那里能看到 dsh-doc（总数 85）。',
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
