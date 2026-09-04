# PowerShell wrapper for run.sh - lets you stay in PowerShell/Windows Terminal
# instead of needing a separate Git Bash window. Plain `bash` on this machine
# resolves to WSL (not Git Bash), which breaks run.sh's Windows-style paths -
# this calls the real Git Bash executable directly, bypassing that.
#
# Usage: .\run.ps1                 (auto-detects device and LAN IP)
#        .\run.ps1 -d SOME_DEVICE  (or any other flutter-run flag - forwarded through)

$gitBash = "C:\Program Files\Git\bin\bash.exe"

if (-not (Test-Path $gitBash)) {
    Write-Error "Git Bash not found at $gitBash - is Git for Windows installed there?"
    exit 1
}

& $gitBash "$PSScriptRoot\run.sh" @args
exit $LASTEXITCODE
