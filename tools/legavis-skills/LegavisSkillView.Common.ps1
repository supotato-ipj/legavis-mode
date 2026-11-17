#Requires -Version 5.1
<#
.SYNOPSIS
  视图目录生成器与脚本级测试共用的辅助函数。

.DESCRIPTION
  生成器（New-LegavisSkillView.ps1）与测试（Test-LegavisSkillView.ps1）读同一份清单、
  认同一批联接目标，规则只留这一处：

    - 清单每行一个技能目录名；`#` 之后是注释，空行忽略；重复行只算一次；
    - 目录名必须匹配 $script:LegavisSkillNamePattern，不合法就抛异常并点名该条目
      （生成器把异常转成非零码退出，测试据此断言「报错点名违规条目」）；
    - 联接目标取条目的 Target，回落到 LinkTarget。

  两个脚本都用 `. $PSScriptRoot\LegavisSkillView.Common.ps1` 点源本文件。

  本文件不单独运行。
#>

# 技能目录名的合法形态：字母或数字开头，后随字母、数字、点、下划线、连字符
$script:LegavisSkillNamePattern = '^[A-Za-z0-9][A-Za-z0-9._-]*$'

# 读清单：每行一个技能目录名，# 之后是注释，空行忽略，重复行只算一次。
# 目录名不合法时抛异常，消息里点名违规条目。
function Get-LegavisManifestNames {
  param([string]$Path)
  $names = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    $name = ($line -split '#', 2)[0].Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    if ($name -notmatch $script:LegavisSkillNamePattern) {
      throw "清单里的条目不是合法的技能目录名：'$name'"
    }
    if (-not $names.Contains($name)) { $names.Add($name) }
  }
  return ,$names
}

# 联接目标：优先 Target，回落到 LinkTarget。
function Get-LegavisLinkTarget {
  param([string]$Path)
  $item = Get-Item -LiteralPath $Path -Force
  $target = $item.Target
  if ($null -eq $target -or @($target).Count -eq 0) { $target = $item.LinkTarget }
  return [string]@($target)[0]
}
