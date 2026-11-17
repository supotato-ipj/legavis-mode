# Runs a JS file with the DSH Electron executable in ELECTRON_RUN_AS_NODE mode (ASAR-aware fs).
# Usage: pwsh -File asar-node.ps1 <script.js> [args...]
param(
  [Parameter(Mandatory = $true)][string]$Script,
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$ScriptArgs
)

$node = $env:DSH_NODE_EXECUTABLE
if (-not $node) { $node = 'D:\programs\dsh\DeepSeek Harness.exe' }

$start = [System.Diagnostics.ProcessStartInfo]::new($node)
foreach ($argument in @('-e', "require(process.argv[1])", '--', $Script) + $ScriptArgs) { $start.ArgumentList.Add($argument) }
$start.Environment['ELECTRON_RUN_AS_NODE'] = '1'
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$start.StandardErrorEncoding = [System.Text.Encoding]::UTF8

$process = [System.Diagnostics.Process]::Start($start)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEndAsync()
$process.WaitForExit()
[Console]::Out.Write($stdout)
[Console]::Error.Write($stderr.Result)
exit $process.ExitCode
