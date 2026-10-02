# Install every skill in this repository into your agent's skills directory.
# Usage: .\install.ps1 [-Target "$HOME\.claude\skills"]
param(
    [string]$Target = ""
)

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Target) {
    $candidates = @(
        "$env:USERPROFILE\.zcode\skills",
        "$env:USERPROFILE\.agents\skills",
        "$env:USERPROFILE\.claude\skills",
        "$env:USERPROFILE\.codex\skills"
    )
    foreach ($d in $candidates) {
        if (Test-Path $d) { $Target = $d; break }
    }
}
if (-not $Target) {
    Write-Error "No skills directory found. Create one, or run: .\install.ps1 -Target C:\path\to\skills"
    exit 1
}

New-Item -ItemType Directory -Force -Path $Target | Out-Null
Get-ChildItem -Directory -Path $RepoDir | ForEach-Object {
    if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
        $dest = Join-Path $Target $_.Name
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse $_.FullName $dest
        Write-Host "Installed: $($_.Name) -> $dest"
    }
}

Write-Host "Done. Restart your agent to pick up the new skills."
