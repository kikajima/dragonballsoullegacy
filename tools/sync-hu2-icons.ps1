param(
    [string]$SourceRepo = "https://github.com/DarkerLegends/HeroesUnited2.git",
    [string]$SourceRef = "master"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DestRoot = Join-Path $RepoRoot "assets\vendor\hu2"
$DestIcons = Join-Path $DestRoot "Icons"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dbsl-hu2-icons-" + [guid]::NewGuid().ToString("N"))

try {
    Write-Host "Cloning HU2 Icons only..."
    git clone --depth 1 --branch $SourceRef --filter=blob:none --sparse $SourceRepo $TempRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone failed." }

    git -C $TempRoot sparse-checkout set Icons
    if ($LASTEXITCODE -ne 0) { throw "sparse-checkout failed." }

    $SourceSha = (git -C $TempRoot rev-parse HEAD).Trim()

    New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
    if (Test-Path $DestIcons) {
        Remove-Item -Recurse -Force $DestIcons
    }

    Copy-Item -Recurse -Force (Join-Path $TempRoot "Icons") $DestRoot

    # Map.dmm is HU2 world-layout/game content, not a visual asset.
    $MapFile = Join-Path $DestIcons "Map.dmm"
    if (Test-Path $MapFile) {
        Remove-Item -Force $MapFile
    }

    $DmiCount = @(Get-ChildItem -Recurse -File $DestIcons -Filter *.dmi).Count
    $PngCount = @(Get-ChildItem -Recurse -File $DestIcons -Filter *.png).Count

    $Readme = @"
# HeroesUnited2 visual asset mirror

Source: $SourceRepo
Source ref: $SourceRef
Source commit: $SourceSha

Imported scope: `Icons/` visual assets only.

Included:
- Characters
- HUD
- Images
- Items
- Other/effects
- Turfs
- Winter Effects.dmi

Excluded:
- `Icons/Map.dmm` (world/map layout, not a visual icon asset)
- all HU2 `.dm` code and gameplay logic

Counts at sync time:
- DMI: $DmiCount
- PNG: $PngCount

These files are kept as upstream source assets. DBSL's DMI loader can read
BYOND DMI PNG metadata directly at runtime.

Licensing note: the upstream repository does not currently expose a clear
license file. Treat this mirror as prototype/reference material until asset
redistribution rights are confirmed.
"@

    Set-Content -Path (Join-Path $DestRoot "README.md") -Value $Readme -Encoding UTF8

    Write-Host ""
    Write-Host "HU2 visual assets synchronized."
    Write-Host "Source commit: $SourceSha"
    Write-Host "DMI files: $DmiCount"
    Write-Host "PNG files: $PngCount"
    Write-Host "Destination: $DestIcons"
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -Recurse -Force $TempRoot
    }
}
