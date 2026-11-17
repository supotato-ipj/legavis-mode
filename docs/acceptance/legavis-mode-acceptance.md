# Legavis 模式验收记录

记录时间：2026-11-17　｜　环境：DSH 0.2.2-rc.3，desktop profile，Windows

本文只记外部可观察行为：模型实际看到的技能目录、实际可用的工具、模式能否挂载并起会话。不断言模式声明的 YAML 结构、视图目录的联接实现方式或 DSH 内部层。

复现命令见每节末尾。

---

## 0. 观测边界：哪些是机械观测，哪些要真开会话

本轮**没有**跑过「一个真实 DSH 会话在 legavis 模式下运行」。规格里的主 seam 是一次真实会话；本轮做的是**产物级机械观测**——用 DSH 真实的技能注册表与真实的 filesystem provider 取出技能目录，用插件管理器与 Config inspect 读行状态。

| 验收面 | 本轮怎么观测的 | 状态 |
|---|---|---|
| 模式包与模式行的安装状态 | `plugin_manager list_bundles` / `list_plugins`（读行状态） | 已机械观测 |
| 模式行的 Config schema 状态 | `Config` inspect 的 `listConfigs`（读投影 schema） | 已机械观测 |
| 模型技能目录（白名单技能，以清单为准） | 真实技能注册表 + 真实 provider，脚本驱动 | 已机械观测 |
| 白名单外技能不可加载 | 同上（`ctx.skills.get()` 返回 undefined） | 已机械观测 |
| 工具目录（`memory_save` 等不存在） | **仅由行状态推断**，未在真会话里看过工具列表 | 待 GUI 会话中确认 |
| 模式选择器里能选中「Legavis 推理模式」 | 客户端侧 roster，命令行代劳不了 | 待 GUI 会话中确认 |
| 斜杠命令触发、子代理派发、案件项目内文件读写 | 需要真会话 | 待 GUI 会话中确认 |

第 6 节的清单是给评审人的 GUI 会话核对项：每条都写成**可观察的行为**，不是内部断言。

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

> **待 GUI 会话中确认**：模式选择器里出现「Legavis 推理模式」并能选中起会话，需在 GUI 里刷新页面后选中验证——模式选择器读的是客户端侧的 roster，本机 GUI 的 HTTP 接口对无凭据请求一律 401，命令行无法代为点击。

---

## 2. 模型技能目录

legavis 模式自己的 `skill-filesystem` 行关掉默认发现根（`includeDefaultRoots: false`）、跟随符号链接（`watchFollowSymlinks: true`），`customSkillDirs` 只指向白名单 junction 视图目录 `C:\Users\HUAWEI\.dsh\legavis-skills`。

验证脚本**从模式包声明里读**这一组配置（`bundles/dsh-legavis-mode/cordis.patch.yml` 的 `skill-filesystem` 行），并按 Loader 的方式求值其中的 `!!js` 路径表达式，所以模式包里写的路径写法真的被跑到，不是脚本里另写一份。

用 DSH 真实的技能注册表 + 真实的 filesystem provider，以 legavis 模式声明里的那一组 `skill-filesystem` 配置取出的技能目录：

- **legavis 模式：40 个技能**（以 `skills-allowlist.txt` 为准），与清单逐条一致——legavis／法律研究系 13 个（`legal-subsumption`、`setup-legavis-skill`、`legavis-intake`、`legavis-spec`、`legavis-report`、`atomic-syllogism`、`attribution-analysis`、`factual-evidence`、`logical-verification`、`normative-analysis`、`provisional-risk-assessment`、`reasoning-process-audit`、`prc-legal-research`）+ matt 系列 27 个。

  这 40 个是**注册表目录**（`ctx.skills.list()` 返回的、与调用方式无关的目录）：`legal-subsumption` 等六个只允许斜杠命令触发的技能也在里面（它们的 frontmatter 带 `disable-model-invocation: true`，模型目录与 `skill` 工具看不到它们，但注册表目录看得见）。模型实际看到的目录是注册表目录去掉这一批，再加上全局层的插件型技能——**模型目录本身待在 GUI 会话中确认**（第 6 节）。

- **对照（默认发现根，同一台机器）：84 个技能**。
- **两者之差 44 个**，全部为白名单外技能，不出现在 legavis 模式里：
  `agent-deck-worktree`、`alibabacloud-workbench-cli`、`arkcli-agent`（这一项是技能 frontmatter 里的 `name`，磁盘上的目录名是 `arkcli-managed-agent`）、`arkcli-api-explorer`、`arkcli-auth`、`arkcli-billing`、`arkcli-chat`、`arkcli-code-example`、`arkcli-config`、`arkcli-connect`、`arkcli-custommodel`、`arkcli-deploy`、`arkcli-doctor`、`arkcli-gen`、`arkcli-helper`、`arkcli-infer-endpoint`、`arkcli-models`、`arkcli-onboard`、`arkcli-plans`、`arkcli-pricing`、`arkcli-profile`、`arkcli-resources`、`arkcli-shared`、`arkcli-train-finetune`、`arkcli-understand`、`arkcli-usage`、`autoglm-browser-agent`、`byted-supabase`、`chief-of-staff`、`claude-handoff`、`diagram-design`、`git-guardrails-claude-code`、`gtd-triage`、`hermes-desktop-update`、`loop-me`、`migrate-to-shoehorn`、`obsidian-annotations`、`resolving-merge-conflicts`、`scaffold-exercises`、`setup-pre-commit`、`setup-ts-deep-modules`、`writing-beats`、`writing-fragments`、`writing-shape`。

  （源技能根 `C:\Users\HUAWEI\.agents\skills` 有 85 个目录，但其中两个目录的 frontmatter `name` 都是 `autoglm-browser-agent`，注册表按 `name` 去重，所以目录数 85、技能数 84。）

**对照基线的含义**：上面的 84 是**本机默认发现根**下的技能数（user-agents 根 `C:\Users\HUAWEI\.agents\skills`），**不等于出厂 standard 模式**。出厂 standard 在默认发现根之外还额外注入 agent-preset 包自带的 `skills` 目录（`customSkillDirs` 指向 `@deepseek-ai/dsh-agent-preset/skills`），因此那里能看到 `dsh-doc`，总数是 85。legavis **刻意不注入**这个目录——它的 `customSkillDirs` 只指向白名单视图目录，所以 `dsh-doc` 不在 legavis 的技能目录里（预期结果，不是漏配）。

**真实会话里还会多出插件型技能**（全局层，模式移不掉，属已知且接受的结果）：`prc-legal-research` 四件套（法规、案例、企业、证券检索）、office 四件套、`diagnose-windows-sandbox-acl`。因此模型可见的技能目录 = 白名单里可自动调用的那批 + 这些插件型技能；插件型技能同样只在真会话里点过数（第 6 节）。

复现：

```powershell
# legavis 配置下的技能目录
pwsh -File tools/asar-read/asar-node.ps1 tools/legavis-skills/verify-legavis-catalog.cjs legavis
# 对照：默认发现根下的技能目录
pwsh -File tools/asar-read/asar-node.ps1 tools/legavis-skills/verify-legavis-catalog.cjs standard
```

（脚本需要绝对路径；`asar-node.ps1` 用 DSH 的 Electron 可执行文件跑 Node，ASAR 里的 `@deepseek-ai/dsh-skill` 与 `dsh-skill-filesystem` 才能被读到。）

读 ASAR 里的其他文件（例如出厂 standard 预设原文、preset registry 源码）用同一个 Electron Node：

```powershell
pwsh -File tools/asar-read/asar-node.ps1 tools/asar-read/cat.js <ASAR 内文件路径> [maxChars]
```

`cat.js` 的限额按**字符**计（`maxChars`），与它内部的 `text.length` / `slice` 一致。

---

## 3. 负向用例

与第 2 节同一个 seam（真实技能注册表 + 真实 provider）：

| 请求 | 结果 | 观测方式 |
|---|---|---|
| 加载白名单外的技能 `arkcli-usage` | 不在技能目录里，`skill` 工具也加载不到（`ctx.skills.get()` 返回 undefined） | 已观测 |
| 同上 `arkcli-gen` / `gtd-triage` / `obsidian-annotations` / `writing-shape` | 同上，均不可用 | 已观测 |
| 记忆类工具 `memory_save` / `memory_delete` | **推断**：`memory` 行已关（`enabled: false`），故不注册——推断自行状态，未在真会话里看过工具列表 | 待 GUI 会话中确认 |
| 记忆类工具 `mcp__openviking__*` | **推断**：`mcp-openviking` 行已关（`enabled: false`），故不注册——同上 | 待 GUI 会话中确认 |

复现：同第 2 节的命令，输出里的 `negative.presentInCatalog` 与 `negative.loadableViaSkillTool` 均为空数组。

工具目录的**实际**观察放在第 6 节的 GUI 核对清单里。

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

`C:\Users\HUAWEI\.dsh\legavis-skills`：40 个条目，逐条是 junction（reparse point），目标为 `C:\Users\HUAWEI\.agents\skills\<技能名>`，每个 `SKILL.md` 可读。重复执行生成脚本结果不变（幂等），源技能根仍 85 个目录，`.skill-lock.json` 未被触碰。

证据取自脚本级测试与生成器实跑：生成器重跑后 40 个联接全部解析到源路径、每个 `SKILL.md` 可读、条目集合前后一致（幂等）；脚本级测试另外断言每个联接目标是源目录里的真实技能目录而非副本。

复现：

```powershell
pwsh -File tools/legavis-skills/New-LegavisSkillView.ps1
pwsh -File tools/legavis-skills/Test-LegavisSkillView.ps1
```

---

## 6. GUI 会话核对清单（待在 GUI 会话中确认）

本轮没有真会话，以下每条都要评审人在 GUI 里开一个 legavis 模式的会话，**按可观察的行为**逐条打勾。每条都写成外部能看到的东西。

### 6.1 模式选择器

- [ ] 刷新 GUI 页面后，新会话的模式选择器里出现「Legavis 推理模式」。
- [ ] 选中它能起会话，不会被拒绝（拒绝时 GUI 会给出原因文案，模式行会被标「加载失败」）。

### 6.2 工具目录

- [ ] 会话开起来后，工具列表里**没有** `memory_save`、`memory_delete`、`mcp__openviking__*`。
- [ ] 工具列表里有文件读写、检索、子代理派发、斜杠命令、问答、待办、呈现这些 standard 同款工具（模式切换不带来能力落差）。

### 6.3 技能目录

- [ ] 会话开起来后，模型技能目录里有白名单里可自动调用的那批 + 插件型技能；没有 arkcli 系列、matt 仓库 in-progress 技能、GTD、Obsidian 等。
- [ ] `dsh-doc` 不在其中（legavis 刻意不注入 agent-preset 包自带的 `skills` 目录）。

### 6.4 斜杠命令触发

- [ ] 输入 `/legal-subsumption` 能拉起总控；`legal-subsumption`、`setup-legavis-skill`、`legavis-spec`、`legavis-report`、`provisional-risk-assessment`、`reasoning-process-audit` 只能用斜杠命令触发。
- [ ] 这六个技能不出现在**模型可自动调用**的技能目录里（它们的 frontmatter 带 `disable-model-invocation: true`）。注意它们**在**注册表的目录里——第 2 节那 40 个是注册表目录，包含这六个；模型目录是注册表目录去掉仅斜杠命令的那批。

### 6.5 子代理派发

- [ ] 会话里能派发独立子代理并拿到回执（legavis 总控的编排依赖它）。

### 6.6 案件项目内文件读写

- [ ] 在案件项目目录里能读文件、能写文件（推理记录、涵摄节点、检查报告要能落盘）。
- [ ] 直接按路径读白名单外技能正文**仍读得到**——这是已知行为（能力级隔离不是路径级隔离），确认它没被误当成失败。

---

## 7. 诊断路径：模式声明出错时怎么找

模式声明出错**不是静默失效**：preset registry 在装载失败时 catch 住错误、记进 `record.broken`，并打一条 warning 日志 `agent preset <id>: <reason>`（见 `docs/research/dsh-preset-research.md` 第 1.1 节）。按下述顺序查：

1. **模式包装上没有、模式行是不是 active**

   ```
   plugin_manager list_bundles      # 看 @local/dsh-legavis-mode 是否 installed / enabled
   plugin_manager list_plugins      # 看 include:preset-legavis 的 enabled 与 fiberPhase
   ```

   行不存在 → 模式包没装或没进 profile 组合；行存在但 `fiberPhase` 不是 `active` → 声明有问题，往下看。

2. **该行的 Config schema 状态**

   `Config` inspect 的 `listConfigs`，按 `name=@deepseek-ai/dsh-agent-preset` 列出全部 preset 行，看 `include:preset-legavis` 的 `status`：

   - `status: schema` → 这一行已按 preset 的 Config schema 校验通过，声明结构本身没问题；
   - 别的状态 → schema 校验没过，问题在声明内容。

3. **该行的投影 schema**

   同一接口带 `entry=include:preset-legavis`，拿到该行投影出来的 JSON Schema（`id` / `plugins` / `order` 五个字段），核对 `config.id` 是 `legavis`、`order` 是 10、`plugins` 里 `skill-filesystem` 行的 `customSkillDirs` 在不在。

4. **warning 里的原因**

   registry 打的那条 `agent preset legavis: <reason>` 就是原因本身。GUI 侧同样有信号：模式选择器给装载失败的模式打「加载失败」徽标，切换被拒时也会带上原因。

5. **模式包声明本身**

   声明在 `bundles/dsh-legavis-mode/cordis.patch.yml`。改完重装模式包（`plugin_manager install_bundle`），再从第 1 步走一遍。

---

## 8. 回滚：一次性撤销本次改动

按顺序执行下面四组命令，即可回到本次改动之前的状态。前三组是 profile 级的，第四组是本仓库的。

1. **卸掉模式包**（模式选择器里的「Legavis 推理模式」随之消失）

   ```
   plugin_manager remove_bundle target=@local/dsh-legavis-mode
   ```

2. **把三个记忆相关行开回来**（恢复日常的记忆召回与写入）

   ```
   plugin_manager set_plugin target=include:memory enabled=true
   plugin_manager set_plugin target=include:mcp-openviking enabled=true
   plugin_manager set_plugin target=include:openviking-policy enabled=true
   ```

3. **删掉视图目录**（只删视图目录里的联接，不碰源技能目录里的任何技能）

   ```powershell
   Remove-Item -LiteralPath 'C:\Users\HUAWEI\.dsh\legavis-skills' -Recurse -Force
   ```

   源技能根 `C:\Users\HUAWEI\.agents\skills` 与 `.skill-lock.json` 不受影响——视图目录里全是联接，删联接不动目标。

4. **仓库分支**：按需取舍。

   - 想留着以后再做：`git branch` 保留 `fix/code-review-findings` 即可，不必删。
   - 想彻底清掉：在主检出目录里 `git branch -D fix/code-review-findings`（若该分支还挂在 worktree 上，先 `git worktree remove <worktree 路径>` 再删分支）。

回滚后验证：`plugin_manager list_bundles` 里不再有 `@local/dsh-legavis-mode`，`plugin_manager list_plugins` 里三行记忆相关行都是 `enabled: true`。

---

## 9. 未纳入本次范围

- 路径级隔离（`@local/dsh-skill-guard` 未启用，见 ADR-0001）。
- 插件型技能从全局层消失（做不到，已知且接受）。
- 记忆库的召回／抽取／合并策略本身（「能召回但不写」需要记忆插件自身的行为项，属另一轮）。
