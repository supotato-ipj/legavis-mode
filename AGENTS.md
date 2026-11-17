# Agent skills

### Issue tracker

Issues and specs are tracked as GitHub Issues in `supotato-ipj/legavis-mode`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: the five canonical roles map to identical GitHub label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, consumed per `docs/agents/domain.md`.

### Legavis 模式

本仓库是 legavis 模式的真相源：`skills-allowlist.txt` 是技能白名单的单一真相源，`bundles/dsh-legavis-mode/` 是模式包（声明 `preset-legavis`），`tools/legavis-skills/` 是视图目录生成脚本与验证脚本。见 `docs/skills-allowlist.md`。验收记录见 `docs/acceptance/legavis-mode-acceptance.md`。

模式隔离是能力级隔离（见 `docs/adr/0001-legavis-mode-as-agent-preset.md`）：白名单外的技能不出现在该模式的技能目录里，`skill` 工具也加载不到；但文件仍在磁盘上，按路径直读仍读得到。

### Legavis 模式纪律

在 legavis 推理模式（本项目的法律推理会话）下：

- **只用白名单技能**：可用的技能是 `skills-allowlist.txt` 列出的 40 个（legavis／法律研究系 13 个 + matt 系列 27 个），加上全局层的插件型技能（`prc-legal-research` 四件套、office 四件套）。清单在 legavis-mode 仓库。
- **不读白名单外技能文件**：不要为了「参考某个技能的做法」去按路径打开白名单外的技能正文（`~/.agents/skills/<白名单外技能>/SKILL.md`）。机制上这些技能加载不到，读它们是绕开隔离；需要某个方法时，改用白名单内的等价技能，或把该技能加入白名单后重跑生成脚本。
- **不写长期记忆库**：本项目不写入用户跨项目记忆库，也不写入 OpenViking 共享库。案件结论一律落进项目的四区目录（`docs/facts`、`docs/argumentation`、`docs/adr`、报告目录）。
- **总控入口唯一**：法律推理的总控必须经 `/legal-subsumption` 进入，不自行启动总控流程。`legal-subsumption`、`setup-legavis-skill`、`legavis-spec`、`legavis-report`、`provisional-risk-assessment`、`reasoning-process-audit` 这几个技能只允许斜杠命令触发，不要用 `skill` 工具直接加载它们。
- **中间产物留在项目内**：推理记录、涵摄节点、检查报告写进项目目录，不留在会话上下文里等下一轮。

案件项目的 `AGENTS.md` 用同一段条款，模板见 `docs/legavis-discipline.md`。
