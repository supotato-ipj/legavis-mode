# Legavis Mode

本仓库定义一个专用于调用 legavis 系列技能的 DSH 模式（agent preset）：它决定某个会话里的 Agent 看得到哪些技能、拿得到哪些工具、会不会写进用户的长期记忆。

## Language

**模式（Mode）**:
DSH 的 agent preset——一份声明式组合，决定选中它的会话里 Agent 挂哪些插件、看哪些技能、用哪些工具。
_Avoid_: 插件集、工作区配置、模式包

**模式包（Mode Bundle）**:
承载一份模式声明的 DSH 插件包（`package.json` + `cordis.patch.yml`），装进 profile 后该模式出现在模式选择器里。
_Avoid_: 插件、配置片段、补丁文件

**技能白名单（Skill Whitelist）**:
某个模式允许 Agent 加载的技能集合；集合外的技能在该模式的技能目录里不出现。
_Avoid_: 技能列表、可用技能

**能力级隔离（Capability-level Isolation）**:
白名单外的技能在机制上不可被 Agent 加载——它不在该模式的技能目录里，`skill` 工具也加载不到；文件本身仍留在磁盘上。
_Avoid_: 硬隔离、安全隔离、权限隔离

**路径级隔离（Path-level Isolation）**:
Agent 连直接读取白名单外的技能文件都做不到，靠文件系统边界而不是技能机制来保证。
_Avoid_: 完全隔离、绝对隔离

**记忆污染（Memory Pollution）**:
一次模式运行把本该属于法律工作记忆的内容写进用户的跨项目记忆库或 OpenViking 共享库。
_Avoid_: 记忆写入、记忆副作用
