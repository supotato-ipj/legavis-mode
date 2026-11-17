# Legavis 模式落在当前 profile 的 agent preset 内

legavis 模式以一个模式包（bundle）声明的 agent preset 形态，落在当前 desktop profile 内；技能隔离靠能力级隔离（模式自己的 `skill-filesystem` 行 + junction 视图目录）实现，不另起独立 profile，也不做路径级隔离。

## Considered Options

- **独立 DSH profile（另起实例，profile 里不装 memory/openviking）**：隔离最彻底，但测试期要复制凭据、迁会话习惯，记忆库/会话/日志全部另起一份，收益不抵成本。
- **装 `dsh-skill-guard` 做宿主级硬闸（路径级隔离）**：能挡住"绕过 skill 工具直接读白名单外技能文件"，但它的两个 seam 是宿主服务，闸门对**所有模式**生效——连日常的 standard 模式一起扫；且它自带 `data/skill-roots.json` 根表，与白名单目录改动耦合。
- **直接改 profile 的 `cordis.patch.yml`**：没有版本管理，插件管理器的写操作可能覆盖。

## Consequences

- 白名单外的技能在 legavis 模式下**机制上不可加载**，但文件仍在磁盘上：模式内带 `pwsh`/`read` 时，agent 仍可直接按路径读到——防线是案件项目 `AGENTS.md` 的纪律条款，不是机制。
- 关闭 `memory` 与 `mcp-openviking` 是 **profile 级**开关，对该 profile 的所有会话生效，不只 legavis 模式；测完必须在 Plugins 页开回来。
- 插件注册型技能（`prc-legal-research` 四件套、office 四件套）位于全局层，任何模式都看得到，模式移不掉——"只剩白名单"是做不到的，"只剩白名单 + 这些插件型技能"是能做到的。
- 模式包一旦声明加载失败，仍会出现在选择器里但带诊断、起不了会话；修复方式是改模式包重装，不影响默认模式。
