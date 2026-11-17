# DSH Agent Preset 调研笔记（只读调研，2026-11-17）

安装：D:\programs\dsh\resources\app.asar\dsh\
profile：desktop（DSH_PROFILE_DIR=C:\Users\HUAWEI\.dsh\profiles\desktop）
DSH CLI 包版本：@deepseek-ai/dsh-* 0.2.2-rc.3（web-app bundle package.json）

## 1. Preset 是什么、放在哪

- preset = `@deepseek-ai/dsh-agent-preset` 插件的一行声明，由 bundle patch 携带。
- 声明行 id 约定 `preset-<id>`；`config.id` 是 preset 身份（会话记录的就是它）。
- 出厂 Web preset 文件：`presets/<id>.patch.yml`，id = standard / ptc / minimal / cordis。
- 存放位置（安装版）：
  - `D:\programs\dsh\resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-web-app\presets\{standard,ptc,minimal,cordis}.patch.yml`
  - bundle patch 顺序：`dsh-web-app/package.json` → `dsh.bundle.patch` = [cordis.patch.yml, presets/standard.patch.yml, presets/ptc.patch.yml, presets/minimal.patch.yml, presets/cordis.patch.yml]
  - profile patch（最后一层）：`C:\Users\HUAWEI\.dsh\profiles\desktop\cordis.patch.yml`
- 旧目录式 preset（`$DSH_HOME/.agent-presets/<id>/preset.yml` + `agent.cordis.yml`）**已废弃，无人读取**。

### 1.1 模式装载失败时的诊断面

preset 装载失败**不抛到启动流程**：`dsh-agent-preset-registry` 在 `activate()` 里 catch 住错误，
把原因记进 `record.broken`，并打一条 warning 日志——

```
agent preset <config.id>: <reason>
```

（`dsh-agent-preset-registry/src/index.ts`：`this.owner.logger.warn(\`agent preset ${record.config.id}: ${record.broken}\`)`）

所以「模式声明出错」表现为**静默挂载失败 + 一条 warning**，不是启动崩溃。三处可查：

| 面 | 查什么 | 怎么查 |
|---|---|---|
| 插件管理器 | 模式包是否已安装、模式行是否 active | `plugin_manager list_bundles` / `plugin_manager list_plugins` |
| Loader 的 Config 目录 | 该行的 schema 状态（`status: schema` 表示已按 preset 的 Config schema 校验通过） | `Config` inspect：`listConfigs` 按 `name=@deepseek-ai/dsh-agent-preset` 列出全部 preset 行 |
| `Config` inspect 单行 | 该行的投影 schema（`id` / `plugins` / `order` 五个字段） | `listConfigs` 带 `entry=include:preset-legavis` |

客户端侧还有一处人眼可见的信号：模式选择器给装载失败的 preset 打「加载失败」徽标
（`dsh-client-ui-agent-preset` 的 `brokenBadge`），切换时也会带上原因（`switchRefused`）。

## 2. Preset schema（真实原文）

`dsh-agent-preset/src/index.ts`：

```ts
static Config: z<Config> = z.object({
  id: z.string().required(),
  name: z.string(),
  description: z.string(),
  order: z.number(),
  // Cordis owns individual plugin schemas; the registry validates entry structure.
  plugins: z.array(z.any()).required(),
}) as z<Config>
```

**只有 5 个字段。没有 skills 白名单、没有 tools 白名单、没有 plugin 启停字段。**

## 3. Scope 分层（关键机制）

- `dsh-scope`：agent scope 的 parent 链 = preset scope → agent scope。
- tools registry（`dsh-tools/src/index.ts`）：`view(scope)` 合并 global 层 + 链上各层；`layers.every(layer => layer.admits(name))` 决定可见性；同名近层遮蔽远层。
- skill registry（`dsh-skill/src/index.ts` + README 第 84 行）：同样的 host+per-scope 分层；
  "host rows and repository plugins land in the global layer, a plugin mounted by an agent preset's standing composition lands in that preset's layer. A read merges the global layer with the viewing scope's chain"
- ⇒ **preset 的 plugins 只能"增加"，不能"裁剪"全局层已注册的东西**，除非显式 restrict。

## 4. 技能（skills）

### 4.1 发现根（skill-filesystem，rank 顺序）
| rank | source | path |
|---|---|---|
| 100 | project-dsh | `<projectRoot>/.dsh/skills` |
| 200 | project-agents | `<projectRoot>/.agents/skills` |
| 300 | custom | `Config.customSkillDirs` |
| 400 | user-dsh | `<dshHome>/skills`（跳过 `.system`） |
| 500 | user-agents | `<agentsHome>/skills` |
| 600 | bundled | `Config.bundledSkillDir` |

`includeDefaultRoots: false` → 去掉 project/user 行 + `$DSH_BUNDLED_SKILL_DIR` 默认值。

### 4.2 技能格式
目录包 `<name>/SKILL.md` 或平铺 `<name>.md`；frontmatter 必需 `name`(kebab-case)+`description`，
可选 `whenToUse`/`metadata`/`disable-model-invocation`/`user-invocable`。
`disable-model-invocation: true` → 该技能不出现在模型目录与 `skill` 工具里（仅 `/name` 手势可用）。

### 4.3 目录/加载器的宿主平面归属（web-app/cordis.patch.yml 542-555）
- base bundle 宿主平面行：`skill`(dsh-skill)、`skill-filesystem`、`tool-skill`。
- web-app 把 `skill-filesystem` 与 `tool-skill` 两行 `disabled: true`，改由 preset 挂载。
- 但 `skill-office`（web-app 308-311 行）**留在宿主平面** → 全局层，任何挂了 `tool-skill` 的 preset 都会看到 office 技能。

## 5. 工具（tools）

- `ctx.tools.register(def)`：注册在调用 ctx 的 scope 层。
- `ctx.tools.restrict(filter)`：`ToolRestriction = { allow?: readonly string[]; deny?: readonly string[] }`
  - 必须在有 scope 的 ctx 里调用（`agent.ctx` 或 preset ctx），否则抛错。
  - 只能点名"全局工具名"；未知名字抛错并列出已知名。
  - 多个 restriction 取交集；**scope 自己的注册永远豁免**（preset 自己注册的工具不受 restriction 影响）。
  - 作用范围 = 该 scope 链向下所有 agent。
- `ctx.tools.guard(guard)`：单调拒绝，排在 `tools/pre-execute` 之后。
- `tools/pre-execute` 事件：allow/deny/ask。

## 6. 本机 profile 的相关行

profile package.json `dsh.profile.bundles`：
```
@deepseek-ai/dsh-base, @deepseek-ai/dsh-web-app, @local/dsh-memory,
@local/dsh-notify, @deepseek-ai/dsh-experimental-auto-review,
@deepseek-ai/dsh-experimental-plugin-market-bundle, dsh-context,
@local/dsh-session-tags, @local/gtd-workbench, @local/dsh-openviking-mcp,
huayu-yuandian-legal-data
```
- `@local/dsh-memory`：`cordis.patch.yml` → `- id: memory / name: '@local/dsh-memory' / disabled: true`；
  profile patch 里 `- id: memory / disabled: false` 打开了它。工具名 `memory_save`、`memory_delete`。
- `@local/dsh-openviking-mcp`：`- id: mcp-openviking / name: '@deepseek-ai/dsh-mcp-client' / serverName: openviking`
  + `- id: openviking-policy / name: '@local/dsh-openviking-mcp'`。
  MCP 工具名 `mcp__openviking__*`（全局层）。
- `@local/dsh-skill-guard` 在 profile dependencies 里但**不在 bundles 列表** → 未被组合。
  它的 README 记录了宿主平面 vs preset 平面的取舍（ADR-0001）。

## 7. 结论（能力/限制）

(a) 技能隔离：**可行但需手写组合**。DSH **没有** preset 级 skills 白名单字段。
    可行做法：preset 内挂 `skill-filesystem`（`includeDefaultRoots: false` + `customSkillDirs: [你的目录]`）
    + `tool-skill`；不挂 `tool-skill` = 该 preset 无任何技能目录/工具。
    限制：宿主平面的 provider（skill-office 等）仍进全局层，仍会出现在目录里。
(b) 禁用插件（memory/openviking）：**只能全局禁用，不能按 preset 禁用**。
    Loader 行的 `disabled` 是 profile 级开关。可用 `ctx.tools.restrict({deny:[...]})` 在 preset 层按工具名隐藏。
(c) 限制可调用工具：**可行**。preset 的 plugins 列表决定 preset 层注册哪些工具；
    再用 preset 层插件调 `ctx.tools.restrict({allow|deny})` 隐藏全局工具。
    注意 preset 不是安全沙箱（YAML/plugins 可执行宿主代码）。
