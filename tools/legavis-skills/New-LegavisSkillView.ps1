#Requires -Version 5.1
<#
.SYNOPSIS
  按技能白名单生成 junction 视图目录。

.DESCRIPTION
  清单（默认仓库根的 skills-allowlist.txt）是技能白名单的单一真相源。
  本脚本为清单里的每个技能在视图根下建一个目录联接（junction），指向用户技能目录里的真实位置——
  不是复制、不是搬移：改了技能正文立刻生效，也不存在第二份会走样的副本。

  行为约定：
    - 清单里的条目名不合法时，点名违规条目并以非零码退出；
    - 清单里的技能在源根不存在时，一次性列出全部缺失项并以非零码退出，不静默跳过；
    - 重复执行结果一致（幂等）；执行前清掉视图根里指向源技能根的陈旧联接；
    - 视图根里的真实目录/文件绝不删除——占着清单槽位时直接报错；
    - 只读源技能根，不改、不移、不删源目录里的任何东西，也不碰 .skill-lock.json。

  清单读取与联接目标读取与测试脚本共用 tools/legavis-skills/LegavisSkillView.Common.ps1。

.EXAMPLE
  pwsh -File tools/legavis-skills/New-LegavisSkillView.ps1
#>
[CmdletBinding()]
param(
  # 清单文件路径（相对路径按仓库根解析）
  [string]$ManifestPath,
  # 源技能根（相对路径按仓库根解析）
  [string]$SourceRoot = 'C:\Users\HUAWEI\.agents\skills',
  # 视图根（相对路径按仓库根解析）
  [string]$ViewRoot = 'C:\Users\HUAWEI\.dsh\legavis-skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 仓库根 = 脚本所在目录（tools/legavis-skills）的上一级
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# 清单读取与联接目标读取与测试脚本共用
. (Join-Path $PSScriptRoot 'LegavisSkillView.Common.ps1')

function Resolve-FullPath {
  param([string]$Path, [string]$Base)
  if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
  return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Write-Fail {
  param([string]$Message)
  [Console]::Error.WriteLine("[legavis-skills] $Message")
  exit 1
}

# 目标是否落在源技能根里（判断陈旧联接该不该清）
function Test-IsUnderRoot {
  param([string]$Path, [string]$Root)
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  return $full.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

# ── 参数解析 ────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = Join-Path $RepoRoot 'skills-allowlist.txt' }
$ManifestPath = Resolve-FullPath $ManifestPath $RepoRoot
$SourceRoot = Resolve-FullPath $SourceRoot $RepoRoot
$ViewRoot = Resolve-FullPath $ViewRoot $RepoRoot

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { Write-Fail "找不到清单文件：$ManifestPath" }
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { Write-Fail "找不到源技能根：$SourceRoot" }
if (Test-IsUnderRoot $ViewRoot $SourceRoot) { Write-Fail "视图根不能放在源技能根里面：$ViewRoot" }
if (Test-IsUnderRoot $SourceRoot $ViewRoot) { Write-Fail "源技能根不能放在视图根里面：$SourceRoot" }

# ── 读清单并核对源目录 ──────────────────────────────────────
try {
  $names = Get-LegavisManifestNames $ManifestPath
}
catch {
  Write-Fail $_.Exception.Message
}
if ($names.Count -eq 0) { Write-Fail "清单是空的：$ManifestPath" }

$missing = @($names | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Container) })
if ($missing.Count -gt 0) {
  Write-Fail ("源技能根里缺少 {0} 个白名单技能：{1}（源根：{2}）" -f $missing.Count, ($missing -join '、'), $SourceRoot)
}

# ── 准备视图根 ──────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $ViewRoot)) {
  New-Item -ItemType Directory -Path $ViewRoot -Force | Out-Null
}

# ── 清理陈旧联接（只删指向源技能根的联接）────────────────────
$removedStale = 0
foreach ($item in @(Get-ChildItem -LiteralPath $ViewRoot -Force)) {
  if ($names.Contains($item.Name)) { continue }
  $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
  if (-not $isReparse) {
    Write-Host "[legavis-skills] 保留（不是联接，删不得）：$($item.Name)"
    continue
  }
  $target = Get-LegavisLinkTarget $item.FullName
  if ([string]::IsNullOrWhiteSpace($target) -or -not (Test-IsUnderRoot $target $SourceRoot)) {
    Write-Host "[legavis-skills] 保留（联接指向源技能根以外）：$($item.Name) -> $target"
    continue
  }
  # 只删联接本身，不动它的目标
  [System.IO.Directory]::Delete($item.FullName)
  $removedStale++
}

# ── 建联接 ──────────────────────────────────────────────────
$created = 0
$alreadyCorrect = 0
foreach ($name in $names) {
  $viewPath = Join-Path $ViewRoot $name
  $sourcePath = Join-Path $SourceRoot $name

  if (Test-Path -LiteralPath $viewPath) {
    $item = Get-Item -LiteralPath $viewPath -Force
    $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    if (-not $isReparse) {
      Write-Fail "视图目录里的 '$name' 是真实目录/文件，不是联接；请人工处理后重跑（$viewPath）"
    }
    $target = Get-LegavisLinkTarget $viewPath
    if (-not [string]::IsNullOrWhiteSpace($target) -and
      [System.IO.Path]::GetFullPath($target).TrimEnd('\').Equals($sourcePath.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
      $alreadyCorrect++
      continue
    }
    # 联接指向别处：换掉这个联接本身
    [System.IO.Directory]::Delete($viewPath)
  }

  New-Item -ItemType Junction -Path $viewPath -Target $sourcePath | Out-Null
  $created++
}

# ── 汇总 ────────────────────────────────────────────────────
Write-Host "[legavis-skills] 视图根：$ViewRoot"
Write-Host "[legavis-skills] 已创建 $created 个联接；已正确 $alreadyCorrect 个；缺失 $($missing.Count) 个；清理陈旧联接 $removedStale 个"
exit 0
