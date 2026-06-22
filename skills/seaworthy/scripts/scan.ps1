# Seaworthy scanner — Windows entry point.
#
# Deliberately a thin wrapper, not a parallel reimplementation of the
# detectors. Re-implementing every check natively in PowerShell would mean two
# copies of the detection logic that can silently drift apart, which is exactly
# the kind of inconsistency reference/false-positive-rules.md warns about. The
# detector scripts are POSIX shell because git ships a POSIX shell on every
# platform this skill targets (Git for Windows includes Git Bash) — so on
# Windows this script just finds a working bash and delegates to scan.sh.
#
# If no bash is found, it says so clearly and points at the manual fallback
# commands in reference/checks-catalog.md rather than failing silently.
param(
  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScanSh = Join-Path $ScriptDir "scan.sh"

if (-not (Test-Path $RepoRoot)) {
  Write-Error "seaworthy: '$RepoRoot' is not a directory"
  exit 1
}

$BashCandidates = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "$env:ProgramFiles\Git\usr\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
)
$Bash = $BashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Bash) {
  $Bash = (Get-Command bash.exe -ErrorAction SilentlyContinue).Source
}
if (-not $Bash) {
  $Bash = (Get-Command wsl.exe -ErrorAction SilentlyContinue).Source
  if ($Bash) {
    & wsl.exe bash "$($ScanSh -replace '\\', '/')" "$($RepoRoot -replace '\\', '/')"
    exit $LASTEXITCODE
  }
}

if (-not $Bash) {
  Write-Host "seaworthy: no bash found (checked Git for Windows and WSL)." -ForegroundColor Yellow
  Write-Host "Install Git for Windows (https://git-scm.com/download/win), which includes Git Bash, then re-run this script." -ForegroundColor Yellow
  Write-Host "Alternatively, ask Claude to run the manual fallback commands listed in reference/checks-catalog.md directly." -ForegroundColor Yellow
  exit 1
}

& $Bash $ScanSh $RepoRoot
exit $LASTEXITCODE
