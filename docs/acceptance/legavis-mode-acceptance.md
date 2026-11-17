# Legavis 模式验收记录

记录时间：2026-11-17　｜　环境：DSH 0.2.2-rc.3，desktop profile，Windows

本文只记外部可观察行为：模型实际看到的技能目录、实际可用的工具、模式能否挂载并起会话。不断言模式声明的 YAML 结构、视图目录的联接实现方式或 DSH 内部层。

复现命令见每节末尾。

---

## 1. 模式包与模式行的安装状态

| 项目 | 结果 |
|---|---|
| 模式包 | `@local/dsh-legavis-mode`，`installed: true`、`enabled: true`、version 1.0.0 |
| 模式包来源 | `link:D:\local_works\test-for-legavis-skill-suit\test-for-legavis-mode\bundles\dsh-legavis-mode` |
| 模式包携带的行 | `preset-legavis` → `@deepseek-ai/dsh-agent-preset` |
| 模式行状态 | `include:preset-legavis`：`enabled: true`、`fiberPhase: active` |
| 模式行配置状态 | `include:preset-legavis`：`status: schema`（已按 preset 的 Config schema 校验通过） |
| profile 组合 | `dsh.profile.bundles` 末尾追加 `@local/dsh-legavis-mode` |
| 默认模式 | 未变：standard 仍是默认；legavis 只是多了一个可选入口 |

Loader 侧的 preset 声明只有五个字段（`id` / `name` / `description` / `order` / `plugins`），`config.id` 是会话记录的模式身份。legavis 的 `config.id` 为 `legavis`，`order` 为 10。

复现：

```
plugin_manager list_bundles      # 找到 @local/dsh-legavis-mode
plugin_manager list_plugins      # 找到 include:preset-legavis
```

> **需要人工确认的一项**：模式选择器里出现「Legavis 推理模式」并能选中起会话，需在 GUI 里刷新页面后选中验证——模式选择器读的是客户端侧的 roster，本机 GUI 的 HTTP 接口对无凭据请求一律 401，命令行无法代为点击。

---

## 2. 模型技能目录

legavis 模式自己的 `skill-filesystem` 行关掉默认发现根（`includeDefaultRoots: false`）、跟随符号链接（`watchFollowSymlinks: true`），`customSkillDirs` 只指向白名单 junction 视图目录 `C:\Users\HUAWEI\.dsh\legavis-skills`。

用 DSH 真实的技能注册表 + 真实的 filesystem provider，以 legavis 模式声明里的那一组 `skill-filesystem` 配置取出的技能目录：

- **legavis 模式：40 个技能**，与 `skills-allowlist.txt` 逐条一致——legavis／法律研究系 13 个（`legal-subsumption`、`setup-legavis-skill`、`legavis-intake`、`legavis-spec`、`legavis-report`、`atomic-syllogism`、`attribution-analysis`、`factual-evidence`、`logical-verification`、`normative-analysis`、`provisional-risk-assessment`、`reasoning-process-audit`、`prc-legal-research`）+ matt 系列 27 个。
- **对照（默认发现根，同一台机器）：84 个技能**。
- **两者之差 44 个**，全部为白名单外技能，不出现在 legavis 模式里：
  `agent-deck-worktree`、`alibabacloud-workbench-cli`、`arkcli-agent`、`arkcli-api-explorer`、`arkcli-auth`、`arkcli-billing`、`arkcli-chat`、`arkcli-code-example`、`arkcli-config`、`arkcli-connect`、`arkcli-custommodel`、`arkcli-deploy`、`arkcli-doctor`、`arkcli-gen`、`arkcli-helper`、`arkcli-infer-endpoint`、`arkcli-models`、`arkcli-onboard`、`arkcli-plans`、`arkcli-pricing`、`arkcli-profile`、`arkcli-resources`、`arkcli-shared`、`arkcli-train-finetune`、`arkcli-understand`、`arkcli-usage`、`autoglm-browser-agent`、`byted-supabase`、`chief-of-staff`、`claude-handoff`、`diagram-design`、`git-guardrails-claude-code`、`gtd-triage`、`hermes-desktop-update`、`loop-me`、`migrate-to-shoehorn`、`obsidian-annotations`、`resolving-merge-conflicts`、`scaffold-exercises`、`setup-pre-commit`、`setup-ts-deep-modules`、`writing-beats`、`writing-fragments`、`writing-shape`。

**真实会话里还会多出插件型技能**（全局层，模式移不掉，属已知且接受的结果）：`prc-legal-research` 四件套（法规、案例、企业、证券检索）、office 四件套、`diagnose-windows-sandbox-acl`。因此「模型技能目录 = 白名单 40 + 插件型技能」，不是「只剩 40」。

复现：

```powershell
# legavis 配置下的技能目录
pwsh -File tools/asar-read/asar-node.ps1 tools/legavis-skills/verify-legavis-catalog.cjs legavis
# 对照：默认发现根下的技能目录
pwsh -File tools/asar-read/asar-node.ps1 tools/legavis-skills/verify-legavis-catalog.cjs standard
```

（脚本需要绝对路径；`asar-node.ps1` 用 DSH 的 Electron 可执行文件跑 Node，ASAR 里的 `@deepseek-ai/dsh-skill` 与 `dsh-skill-filesystem` 才能被读到。）

---

## 3. 负向用例

与第 2 节同一个 seam（真实技能注册表 + 真实 provider）：

| 请求 | 结果 |
|---|---|
| 加载白名单外的技能 `arkcli-usage` | 不在技能目录里，`skill` 工具也加载不到（`ctx.skills.get()` 返回 undefined） |
| 同上 `arkcli-gen` / `gtd-triage` / `obsidian-annotations` / `writing-shape` | 同上，均不可用 |
| 记忆类工具 `memory_save` / `memory_delete` | 不存在（`memory` 行已关） |
| 记忆类工具 `mcp__openviking__*` | 不存在（`mcp-openviking` 行已关） |

复现：同第 2 节的命令，输出里的 `negative.presentInCatalog` 与 `negative.loadableViaSkillTool` 均为空数组。

### 已知行为（不作失败断言）

**直接按路径读取白名单外技能正文仍然读得到。** 能力级隔离不是路径级隔离：白名单外的技能文件仍在磁盘上，legavis 模式带 `pwsh`／`read`，agent 直接按路径读照样读得到（实测 `C:\Users\HUAWEI\.agents\skills\arkcli-usage\SKILL.md` 仍可读）。

防线是纪律条款（`AGENTS.md` 里的 legavis 纪律），不是机制。DSH 官方口径：preset 不是安全沙箱。详见 ADR-0001。

---

## 4. 记忆类能力的开关状态

测试期手动关闭三行（profile 级开关，互不依赖）：

| 行 | 模块 | 状态 |
|---|---|---|
| `include:memory` | `@local/dsh-memory` | `enabled: false`、`fiberPhase: null` |
| `include:mcp-openviking` | `@deepseek-ai/dsh-mcp-client`（serverName `openviking`） | `enabled: false`、`fiberPhase: null` |
| `include:openviking-policy` | `@local/dsh-openviking-mcp` | `enabled: false`、`fiberPhase: null` |

`openviking-policy` 一并关，避免留下「要写记忆」的提示段。

**测试结束必须开回来**，恢复命令：

```
plugin_manager set_plugin target=include:memory enabled=true
plugin_manager set_plugin target=include:mcp-openviking enabled=true
plugin_manager set_plugin target=include:openviking-policy enabled=true
```

已知代价：这是 profile 级开关，对 desktop profile 的所有会话生效，不只 legavis 模式——整个 profile 一段时间内没有记忆召回与写入。

---

## 5. 视图目录

`C:\Users\HUAWEI\.dsh\legavis-skills`：40 个条目，逐条是 junction（reparse point），目标为 `C:\Users\HUAWEI\.agents\skills\<技能名>`，每个 `SKILL.md` 可读。重复执行生成脚本结果不变（已正确 40、缺失 0），源技能根仍 85 个目录，`.skill-lock.json` 未被触碰。

复现：

```powershell
pwsh -File tools/legavis-skills/New-LegavisSkillView.ps1
pwsh -File tools/legavis-skills/Test-LegavisSkillView.ps1
```

---

## 6. 未纳入本次范围

- 路径级隔离（`@local/dsh-skill-guard` 未启用，见 ADR-0001）。
- 插件型技能从全局层消失（做不到，已知且接受）。
- 记忆库的召回／抽取／合并策略本身（「能召回但不写」需要记忆插件自身的行为项，属另一轮）。
