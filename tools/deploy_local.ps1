# Deploys the isiStatsForever working tree into the local WoW Forever AddOns folder.
#
# The repo lives outside WoW (C:\Git\isiStatsForever); WoW only gets the addon
# files. The file set matches the release zip in .github/workflows/release.yml:
# isiStatsForever.toc, *.lua (top level), LICENSE, media/. Everything else in the
# target is removed. Never creates junctions or symlinks and never copies .git
# (Battle.net's permission/loose-files checks react badly to both).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\deploy_local.ps1
#   ... -Target "<WoW>\_forever_\Interface\AddOns\isiStatsForever"
#   ... -WhatIf      # only list what would change

[CmdletBinding()]
param(
    [string]$Target = "C:\World of Warcraft\_forever_\Interface\AddOns\isiStatsForever",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.TrimEnd('\')

if (-not (Test-Path (Join-Path $repo "isiStatsForever.toc"))) {
    throw "isiStatsForever.toc not found in $repo"
}
if ($Target.TrimEnd('\') -ieq $repo) { throw "Target equals the repo folder" }
if ((Split-Path $Target -Leaf) -ne "isiStatsForever") {
    throw "Target must end in \isiStatsForever (got $Target)"
}

$files = @(Get-ChildItem $repo -File | Where-Object {
    $_.Name -eq "isiStatsForever.toc" -or $_.Name -eq "LICENSE" -or $_.Extension -eq ".lua"
} | ForEach-Object Name)
$dirs = @("media")
$keep = $files + $dirs

New-Item -ItemType Directory -Force -Path $Target | Out-Null

# Remove everything at the top level that is not part of the addon.
Get-ChildItem $Target -Force | Where-Object { $keep -notcontains $_.Name } | ForEach-Object {
    if ($WhatIf) { Write-Host "would remove $($_.FullName)" }
    else { Remove-Item $_.FullName -Recurse -Force }
}

$common = @("/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:1", "/NP", "/NJH", "/NDL")
if ($WhatIf) { $common += "/L" }

$rcArgs = @($repo, $Target) + $files + $common
& robocopy @rcArgs
if ($LASTEXITCODE -ge 8) { throw "robocopy (files) failed (exit $LASTEXITCODE)" }

foreach ($d in $dirs) {
    $rcArgs = @((Join-Path $repo $d), (Join-Path $Target $d), "/MIR") + $common
    & robocopy @rcArgs
    if ($LASTEXITCODE -ge 8) { throw "robocopy ($d) failed (exit $LASTEXITCODE)" }
}

if ($WhatIf) { Write-Host "[dry run] nothing changed" }
else { Write-Host "[OK] deployed $repo -> $Target" }
