# PowerShell wrapper for run.sh - lets you stay in PowerShell/Windows Terminal
# instead of needing a separate Git Bash window. Plain `bash` on this machine
# resolves to WSL (not Git Bash), which breaks run.sh's Windows-style paths -
# this calls the real Git Bash executable directly, bypassing that.
#
# Usage: .\backend\run.ps1   (from the project root, or .\run.ps1 from here)

$gitBash = "C:\Program Files\Git\bin\bash.exe"

if (-not (Test-Path $gitBash)) {
    Write-Error "Git Bash not found at $gitBash - is Git for Windows installed there?"
    exit 1
}

& $gitBash "$PSScriptRoot\run.sh" @args
exit $LASTEXITCODE
