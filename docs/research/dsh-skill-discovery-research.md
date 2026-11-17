# DSH 技能发现机制与本机技能清单（只读调研，2026-11-17）

安装：`D:\programs\dsh\resources\app.asar\dsh\`　profile：`desktop`　DSH 版本：`0.2.2-rc.3`
环境：`DSH_HOME=C:\Users\HUAWEI\.dsh`，`DSH_AGENTS_HOME` 未设置（回落 `~/.agents`），`DSH_BUNDLED_SKILL_DIR` 为空。

## 1. 发现者与发现根

发现者是 `@deepseek-ai/dsh-skill-filesystem`（`README.md` 为权威说明）。发现根按 rank 排序：

| rank | source | 路径模板 | 本机实测 |
|---|---|---|---|
| 100 | project-dsh | `<projectRoot>/.dsh/skills` | 不存在 |
| 200 | project-agents | `<projectRoot>/.agents/skills` | 不存在 |
| 300 | custom | `Config.customSkillDirs` | 由模式注入 |
| 400 | user-dsh | `<dshHome>/skills` | 不存在 |
| 500 | user-agents | `<agentsHome>/skills` | **存在，85 个技能目录** |
| 600 | bundled | `Config.bundledSkillDir` | 由模式的 `customSkillDirs` 覆盖 |

`projectRoot` = 最近的含 `.git` 的祖先目录，无 `.git` 则用 cwd。
`includeDefaultRoots: false` 会去掉 project/user 各行与 bundled 默认值，只剩 `customSkillDirs`。

## 2. 发现规则与 frontmatter

- 只识别一层：`<root>/<name>/SKILL.md` 或 `<root>/<name>.md`；嵌套不发现。
- frontmatter 必需 `name`（kebab-case）、`description`；可选 `whenToUse`/`metadata`/`disable-model-invocation`/`user-invocable`。
- `disable-model-invocation: true` → 不进模型目录、也不进 `skill` 工具，只能 `/name` 手势触发。

## 3. 本机技能来源

| 来源 | 内容 | 层 |
|---|---|---|
| `~/.agents/skills` | 85 个目录 | 模式层（standard 的 `skill-filesystem` 默认根） |
| `huayu-yuandian-legal-data` 包 | `prc-legal-research-{law,case,company,securities}`，用 `ctx.skills.register()` 注册 | **全局层** |
| `dsh-skill-office`（宿主行 `skill-office`） | `office`、`office-docx`、`office-pptx`、`office-xlsx` | **全局层** |
| `dsh-agent-preset` 包 `skills/` | `dsh-doc`（standard 模式的 `customSkillDirs` 注入） | 模式层 |
| `dsh-sandbox-windows-acl` 资产 | `diagnose-windows-sandbox-acl` | 全局层 |

## 4. 本机清单实测

| 指标 | 数值 |
|---|---|
| `~/.agents/skills` 技能目录总数 | 85 |
| 模型可自动调用（进模型上下文） | **56** |
| 仅斜杠命令（不进上下文） | **29** |
| 56 个模型可见技能的 name+description 合计 | **14,496 字符**（约 5k–8k tokens） |
| 其中 arkcli 系列（24 个） | **7,224 字符**，平均 301 字符/条 |

> 结论：进上下文的只有 name + description，正文只在调用 `skill` 工具时才加载。arkcli 占了模型可见目录的约一半。

## 5. legavis / 法律研究系技能

文件型 13 个（`~/.agents/skills`）：`legal-subsumption`✱、`setup-legavis-skill`✱、`legavis-intake`、`legavis-spec`✱、`legavis-report`✱、`atomic-syllogism`、`attribution-analysis`、`factual-evidence`、`logical-verification`、`normative-analysis`、`provisional-risk-assessment`✱、`reasoning-process-audit`✱、`prc-legal-research`（✱ = 仅斜杠命令）。
插件注册型 4 个：`prc-legal-research-{law,case,company,securities}-search/compliance`（全局层，模式移不掉也不需要移）。
合计 17 个。

## 6. 隔离抓手与限制

DSH **没有**"按技能名白名单"的配置。可用抓手只有三种：

1. 模式内挂 `skill-filesystem`（`includeDefaultRoots: false` + `customSkillDirs`）→ 只暴露指定目录。
2. 模式内不挂 `tool-skill` → 该模式没有任何技能目录（`minimal` 模式即如此）。
3. 改技能 frontmatter 的 `disable-model-invocation` → 改的是技能文件本身，且对所有模式生效。

限制：全局层的 provider（office、prc 四件套等）任何模式都看得到；preset 不是安全沙箱。

## 7. 备份与历史（不参与发现）

- `C:\Users\HUAWEI\.agents\legavis-skill-backups\1.0.0-20261116\`：11 个技能目录 + `UPGRADE-RECEIPT.md`
- `C:\Users\HUAWEI\.agents\skills-history\pre-legavis-20261114\atomic-syllogism`
- `C:\Users\HUAWEI\.agents\.skill-lock.json`：来源锁（mattpocock/skills、skills.volces.com、cathrynlavery/diagram-design），**不含 legavis 条目**——legavis 系为手工放置，搬移/复制不影响记账。

## 8. 本机已装但未启用的相关件

`@local/dsh-skill-guard` 在 profile 的 `dependencies` 里但**不在 `dsh.profile.bundles` 里** → 当前未被组合。它带 `data/skill-roots.json`（复刻 DSH 四个发现根）与 `data/whitelist.json`（路径前缀白名单），其自身 README 记录了"宿主平面 vs 模式平面"的取舍（ADR-0001）。
