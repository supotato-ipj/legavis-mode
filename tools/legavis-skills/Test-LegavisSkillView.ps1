#Requires -Version 5.1
<#
.SYNOPSIS
  视图目录生成脚本的脚本级测试：只断言产物，不断言命令拼写。

.DESCRIPTION
  用例：
    a) 清单里的每个技能在视图目录里各自可读到 SKILL.md；
    b) 重复执行生成器，视图目录条目集合不变（幂等）；
    c) 清单含不存在的技能时，生成器失败且报错点名缺失项；
    d) 视图目录里的条目是联接（junction），指向源目录的真实技能目录，不是副本；
    e) 清单含非法技能名时，生成器失败且报错点名违规条目。

  清单读取与联接目标读取与生成器共用 tools/legavis-skills/LegavisSkillView.Common.ps1，
  技能名校验因此只有一份实现，且被本脚本的用例 e 覆盖。

  所有用例都用临时视图目录，不触碰真实的 C:\Users\HUAWEI\.dsh\legavis-skills。

  运行：pwsh -File tools/legavis-skills/Test-LegavisSkillView.ps1
#>
[CmdletBinding()]
param(
  # 源技能根（真实技能目录所在处）
  [string]$SourceRoot = 'C:\Users\HUAWEI\.agents\skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Generator = Join-Path $RepoRoot 'tools\legavis-skills\New-LegavisSkillView.ps1'
$Manifest = Join-Path $RepoRoot 'skills-allowlist.txt'

# 清单读取与联接目标读取与生成器共用
. (Join-Path $PSScriptRoot 'LegavisSkillView.Common.ps1')

# 白名单条目数的基线：规格钉死的值。清单增删技能时必须同步更新本常量，
# 否则下面的用例会失败——这是有意让基线变更显式发生的唯一一处。
$script:ExpectedAllowlistSize = 40

# ── 断言助手（Pester 不可用时的最小实现）────────────────────
# 本机若装有 Pester 5 及以上，可用 Invoke-Pester 跑同一批用例；
# 但 Pester 3.x 的断言语法与退出码语义与 5.x 不同，按票据要求不安装任何东西，
# 因此脚本自带断言助手，失败即抛异常、进程退出码非零。
$script:AssertionCount = 0

function Assert-True {
  param([bool]$Condition, [string]$Message)
  $script:AssertionCount++
  if (-not $Condition) { throw "断言失败：$Message" }
}

function Assert-Equal {
  param($Expected, $Actual, [string]$Message)
  $script:AssertionCount++
  if ($Expected -ne $Actual) { throw "断言失败：$Message（期望 '$Expected'，实际 '$Actual'）" }
}

function Assert-Contains {
  param([string]$Haystack, [string]$Needle, [string]$Message)
  $script:AssertionCount++
  if (-not $Haystack.Contains($Needle)) { throw "断言失败：$Message（输出里没有 '$Needle'）" }
}

# ── 产物辅助 ────────────────────────────────────────────────
function Get-ViewEntries {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  return @(Get-ChildItem -LiteralPath $Path -Force | Select-Object -ExpandProperty Name | Sort-Object)
}

function Invoke-Generator {
  param([string[]]$Arguments)
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = (Get-Command pwsh -ErrorAction Stop).Source
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
  foreach ($argument in $Arguments) { $psi.ArgumentList.Add($argument) }
  $process = [System.Diagnostics.Process]::Start($psi)
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

# 生成器调用参数：所有用例共用同一组参数，只有清单与视图根不同。
function New-GeneratorArguments {
  param(
    [string]$ViewRoot,
    [string]$ManifestPath = $Manifest
  )
  return @(
    '-NoProfile', '-File', $Generator,
    '-ManifestPath', $ManifestPath,
    '-SourceRoot', $SourceRoot,
    '-ViewRoot', $ViewRoot
  )
}

# ── 用例 ────────────────────────────────────────────────────

function Test-ManifestEntriesAreReadable {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-a-" + [guid]::NewGuid().ToString('N'))
  try {
    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot)
    Assert-Equal 0 $run.ExitCode "生成器应当成功退出（stderr：$($run.StdErr)）"

    $names = Get-LegavisManifestNames $Manifest
    Assert-Equal $script:ExpectedAllowlistSize $names.Count "清单条目数应当等于基线 $script:ExpectedAllowlistSize"

    foreach ($name in $names) {
      $skillFile = Join-Path $viewRoot (Join-Path $name 'SKILL.md')
      Assert-True (Test-Path -LiteralPath $skillFile) "视图目录里应有 $name\SKILL.md"
      $head = Get-Content -LiteralPath $skillFile -TotalCount 1
      Assert-True (-not [string]::IsNullOrWhiteSpace($head)) "$name\SKILL.md 应可读且非空"
    }
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
  }
}

function Test-GeneratorIsIdempotent {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-b-" + [guid]::NewGuid().ToString('N'))
  try {
    $arguments = New-GeneratorArguments -ViewRoot $viewRoot
    $first = Invoke-Generator $arguments
    Assert-Equal 0 $first.ExitCode "第一次执行应当成功退出（stderr：$($first.StdErr)）"
    $afterFirst = Get-ViewEntries $viewRoot

    $second = Invoke-Generator $arguments
    Assert-Equal 0 $second.ExitCode "第二次执行应当成功退出（stderr：$($second.StdErr)）"
    $afterSecond = Get-ViewEntries $viewRoot

    Assert-Equal ($afterFirst -join ',') ($afterSecond -join ',') "重复执行后视图目录条目集合应不变"

    $names = Get-LegavisManifestNames $Manifest
    foreach ($name in $names) {
      Assert-True (Test-Path -LiteralPath (Join-Path $viewRoot (Join-Path $name 'SKILL.md'))) `
        "重复执行后 $name\SKILL.md 仍应可读"
    }
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
  }
}

function Test-MissingSkillFailsLoudly {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-c-" + [guid]::NewGuid().ToString('N'))
  $badManifest = Join-Path $env:TEMP ("legavis-manifest-c-" + [guid]::NewGuid().ToString('N') + '.txt')
  try {
    $names = Get-LegavisManifestNames $Manifest
    $bogus = @('no-such-skill-alpha', 'no-such-skill-beta')
    $lines = @($names[0], $bogus[0], $names[1], $bogus[1]) + ($names | Select-Object -Skip 2)
    [System.IO.File]::WriteAllLines($badManifest, $lines)

    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot -ManifestPath $badManifest)
    $output = $run.StdOut + "`n" + $run.StdErr
    Assert-True ($run.ExitCode -ne 0) "清单含不存在的技能时生成器应当以非零码退出（输出：$output）"
    Assert-Contains $output $bogus[0] "报错应当点名缺失技能 $($bogus[0])"
    Assert-Contains $output $bogus[1] "报错应当点名缺失技能 $($bogus[1])"
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
    if (Test-Path -LiteralPath $badManifest) { Remove-Item -LiteralPath $badManifest -Force }
  }
}

function Test-IllegalSkillNameFailsLoudly {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-g-" + [guid]::NewGuid().ToString('N'))
  $badManifest = Join-Path $env:TEMP ("legavis-manifest-g-" + [guid]::NewGuid().ToString('N') + '.txt')
  try {
    $names = Get-LegavisManifestNames $Manifest
    # 非法名：含空格与中文，匹配不了技能目录名的合法形态
    $illegal = 'bad skill 名'
    $lines = @($names[0], $illegal) + ($names | Select-Object -Skip 1)
    [System.IO.File]::WriteAllLines($badManifest, $lines)

    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot -ManifestPath $badManifest)
    $output = $run.StdOut + "`n" + $run.StdErr
    Assert-True ($run.ExitCode -ne 0) "清单含非法技能名时生成器应当以非零码退出（输出：$output）"
    Assert-Contains $output $illegal "报错应当点名违规条目 '$illegal'"
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
    if (Test-Path -LiteralPath $badManifest) { Remove-Item -LiteralPath $badManifest -Force }
  }
}

function Test-ViewEntriesAreLinks {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-d-" + [guid]::NewGuid().ToString('N'))
  try {
    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot)
    Assert-Equal 0 $run.ExitCode "生成器应当成功退出（stderr：$($run.StdErr)）"

    $names = Get-LegavisManifestNames $Manifest
    foreach ($name in $names) {
      $viewPath = Join-Path $viewRoot $name
      $item = Get-Item -LiteralPath $viewPath -Force
      Assert-True (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) `
        "$name 应是联接（reparse point），不是副本"
      $target = Get-LegavisLinkTarget $viewPath
      $expected = Join-Path $SourceRoot $name
      Assert-Equal $expected $target "$name 的联接目标应当是源目录里的真实技能目录"
    }
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
  }
}

function Test-StaleLinksAreCleanedAndSourceUntouched {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-e-" + [guid]::NewGuid().ToString('N'))
  $staleName = 'arkcli-usage'
  $keepName = 'my-notes'
  try {
    New-Item -ItemType Directory -Path $viewRoot -Force | Out-Null
    # 陈旧联接：指向源技能根、但不在清单里
    New-Item -ItemType Junction -Path (Join-Path $viewRoot $staleName) `
      -Target (Join-Path $SourceRoot $staleName) | Out-Null
    # 用户自己放的真实目录：绝不能删
    $keepPath = Join-Path $viewRoot $keepName
    New-Item -ItemType Directory -Path $keepPath -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $keepPath 'note.txt'), 'keep me')

    $sourceBefore = @(Get-ChildItem -LiteralPath $SourceRoot -Force).Count
    $lockPath = Join-Path (Split-Path -Parent $SourceRoot) '.skill-lock.json'
    $lockStamp = if (Test-Path -LiteralPath $lockPath) { (Get-Item -LiteralPath $lockPath).LastWriteTimeUtc } else { $null }

    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot)
    Assert-Equal 0 $run.ExitCode "生成器应当成功退出（stderr：$($run.StdErr)）"

    Assert-True (-not (Test-Path -LiteralPath (Join-Path $viewRoot $staleName))) `
      "陈旧联接 $staleName 应当被清理"
    Assert-True (Test-Path -LiteralPath (Join-Path $SourceRoot $staleName)) `
      "清理陈旧联接不应动到源目录里的 $staleName"
    Assert-True (Test-Path -LiteralPath (Join-Path $keepPath 'note.txt')) `
      "用户自己放的真实目录 $keepName 及其内容不应被删除"

    Assert-Equal $sourceBefore (@(Get-ChildItem -LiteralPath $SourceRoot -Force).Count) `
      "源技能根的条目数不应改变"
    if ($null -ne $lockStamp) {
      Assert-Equal $lockStamp (Get-Item -LiteralPath $lockPath).LastWriteTimeUtc `
        '.skill-lock.json 不应被触碰'
    }
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
  }
}

function Test-RealDirectoryInSlotFailsInsteadOfDeleting {
  $viewRoot = Join-Path $env:TEMP ("legavis-view-f-" + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Path $viewRoot -Force | Out-Null
    $slot = Join-Path $viewRoot 'tdd'
    New-Item -ItemType Directory -Path $slot -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $slot 'mine.txt'), 'do not delete')

    $run = Invoke-Generator (New-GeneratorArguments -ViewRoot $viewRoot)
    Assert-True ($run.ExitCode -ne 0) "清单槽位被真实目录占住时生成器应当以非零码退出（输出：$($run.StdOut)$($run.StdErr)）"
    Assert-Contains ($run.StdOut + $run.StdErr) 'tdd' "报错应当点名被占用的槽位 tdd"
    Assert-True (Test-Path -LiteralPath (Join-Path $slot 'mine.txt')) "占槽位的真实目录不应被删除"
  }
  finally {
    if (Test-Path -LiteralPath $viewRoot) { Remove-Item -LiteralPath $viewRoot -Recurse -Force }
  }
}

# ── 跑用例 ──────────────────────────────────────────────────
$cases = @(
  @{ Name = '清单里的每个技能在视图目录可读到 SKILL.md'; Body = ${function:Test-ManifestEntriesAreReadable} }
  @{ Name = '重复执行生成器，视图目录条目集合不变（幂等）'; Body = ${function:Test-GeneratorIsIdempotent} }
  @{ Name = '清单含不存在的技能时生成器失败并点名缺失项'; Body = ${function:Test-MissingSkillFailsLoudly} }
  @{ Name = '清单含非法技能名时生成器失败并点名违规条目'; Body = ${function:Test-IllegalSkillNameFailsLoudly} }
  @{ Name = '视图目录里的条目是联接而非副本'; Body = ${function:Test-ViewEntriesAreLinks} }
  @{ Name = '陈旧联接被清理，用户目录与源技能根不被改动'; Body = ${function:Test-StaleLinksAreCleanedAndSourceUntouched} }
  @{ Name = '清单槽位被真实目录占住时报错而不是删除'; Body = ${function:Test-RealDirectoryInSlotFailsInsteadOfDeleting} }
)

$failed = 0
foreach ($case in $cases) {
  try {
    & $case.Body
    Write-Host "PASS  $($case.Name)" -ForegroundColor Green
  }
  catch {
    $failed++
    Write-Host "FAIL  $($case.Name)" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "断言数：$script:AssertionCount；用例：$($cases.Count)；失败：$failed"
if ($failed -gt 0) { exit 1 }
exit 0
