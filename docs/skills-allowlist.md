# 技能白名单与 junction 视图目录

legavis 模式的技能白名单是一份清单文件，视图目录是脚本按清单生成的联接目录。两者都只服务能力级隔离：白名单外的技能不出现在该模式的技能目录里（见 ADR-0001）。

## 单一真相源

`skills-allowlist.txt`（仓库根）是技能白名单的唯一真相源：每行一个技能目录名，共 40 个——legavis／法律研究系 13 个 + matt 系列 27 个。`#` 开头是分区注释，空行忽略。

白名单变更只改清单，不改模式声明。

## 视图目录

生成脚本 `tools/legavis-skills/New-LegavisSkillView.ps1` 按清单建视图目录：

- 视图根默认 `C:\Users\HUAWEI\.dsh\legavis-skills`（`-ViewRoot` 覆盖）
- 源根默认 `C:\Users\HUAWEI\.agents\skills`（`-SourceRoot` 覆盖）
- 清单默认取仓库根的 `skills-allowlist.txt`（`-ManifestPath` 覆盖）

视图目录里每个白名单技能是一个 **junction（目录联接）**，指向源目录里的真实技能目录——不是复制、不是搬移。改了技能正文，legavis 模式立刻生效，也不存在第二份会走样的副本。脚本只读源技能根，不改、不移、不删源目录里的任何东西，也不碰 `.skill-lock.json`。

## 增删技能

1. 编辑 `skills-allowlist.txt`（加一行或删一行）；
2. 重跑生成脚本：

```powershell
pwsh -File tools/legavis-skills/New-LegavisSkillView.ps1
```

脚本可重复执行：已正确的联接原样保留，指向源技能根的陈旧联接被清掉，清单里的技能在源目录不存在时一次性列出全部缺失项并以非零码退出，不静默跳过。视图根里用户自己放的真实目录不会被删除——它占着清单槽位时脚本报错，让人先人工处理。

## 测试

```powershell
pwsh -File tools/legavis-skills/Test-LegavisSkillView.ps1
```

脚本级测试只断言产物：清单里的每个技能在视图目录里各自可读到 `SKILL.md`；重复执行后条目集合不变；清单含不存在的技能时报错并点名缺失项；视图条目是联接而非副本。用例一律走临时视图目录，不触碰真实的 `C:\Users\HUAWEI\.dsh\legavis-skills`。
