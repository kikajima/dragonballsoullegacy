param(
    [string]$GbaArchive = "",
    [string]$Hu2Archive = "",
    [string]$Branch = "develop",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Find-Archive {
    param(
        [string]$ExplicitPath,
        [string]$FileName
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        return $resolved.Path
    }

    $roots = @(
        (Get-Location).Path,
        $PSScriptRoot,
        (Split-Path $PSScriptRoot -Parent),
        (Join-Path $env:USERPROFILE "Downloads"),
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "Documents")
    ) | Select-Object -Unique

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $direct = Join-Path $root $FileName
        if (Test-Path -LiteralPath $direct) {
            return (Resolve-Path -LiteralPath $direct).Path
        }

        $found = Get-ChildItem -LiteralPath $root -Filter $FileName -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $found) {
            return $found.FullName
        }
    }

    throw "Nao encontrei '$FileName'. Passe o caminho explicitamente, por exemplo: -GbaArchive 'C:\\...\\dragonballgba.rar'."
}

function Find-RarExtractor {
    $candidates = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe",
        "C:\Program Files\WinRAR\UnRAR.exe",
        "C:\Program Files\WinRAR\WinRAR.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    foreach ($commandName in @("7z", "7zz", "unrar")) {
        $cmd = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return $cmd.Source
        }
    }

    throw @"
Nenhum extrator RAR foi encontrado.
Instale 7-Zip ou WinRAR e rode novamente.
Com winget: winget install --id 7zip.7zip -e
"@
}

function Expand-RarArchive {
    param(
        [string]$Extractor,
        [string]$Archive,
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $name = [System.IO.Path]::GetFileName($Extractor).ToLowerInvariant()

    if ($name -like "7z*") {
        & $Extractor x "-o$Destination" -y -- $Archive | Out-Host
    }
    elseif ($name -eq "unrar.exe" -or $name -eq "unrar") {
        & $Extractor x -y $Archive "$Destination\" | Out-Host
    }
    elseif ($name -eq "winrar.exe") {
        & $Extractor x -ibck -y $Archive "$Destination\" | Out-Host
    }
    else {
        throw "Extrator RAR nao suportado: $Extractor"
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao extrair '$Archive' (exit code $LASTEXITCODE)."
    }
}

function Copy-TreeFiltered {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$Extensions
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Pasta esperada nao encontrada apos extracao: $Source"
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $sourceRoot = (Resolve-Path -LiteralPath $Source).Path

    $files = Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | Where-Object {
        $Extensions -contains $_.Extension.ToLowerInvariant()
    }

    foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($sourceRoot, $file.FullName)
        $target = Join-Path $Destination $relative
        $targetDir = Split-Path $target -Parent
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }

    return @($files).Count
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    throw "Este script precisa ser executado dentro do clone Git do DBSL."
}

$gba = Find-Archive -ExplicitPath $GbaArchive -FileName "dragonballgba.rar"
$hu2 = Find-Archive -ExplicitPath $Hu2Archive -FileName "DBSL.rar"
$extractor = Find-RarExtractor

Write-Host "==> Repositorio: $RepoRoot" -ForegroundColor Cyan
Write-Host "==> GBA sprites: $gba" -ForegroundColor Cyan
Write-Host "==> HU2 archive: $hu2" -ForegroundColor Cyan
Write-Host "==> Extrator: $extractor" -ForegroundColor Cyan

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dbsl-sprites-" + [guid]::NewGuid().ToString("N"))
$GbaTemp = Join-Path $TempRoot "gba"
$Hu2Temp = Join-Path $TempRoot "hu2"

try {
    Write-Host "`n==> Extraindo sprites GBA..." -ForegroundColor Yellow
    Expand-RarArchive -Extractor $extractor -Archive $gba -Destination $GbaTemp

    Write-Host "`n==> Extraindo HU2 Dev..." -ForegroundColor Yellow
    Expand-RarArchive -Extractor $extractor -Archive $hu2 -Destination $Hu2Temp

    $gbaDest = Join-Path $RepoRoot "assets\vendor\dragon_ball_gba"
    $hu2Dest = Join-Path $RepoRoot "assets\vendor\hu2_dev\Icons"

    if (Test-Path -LiteralPath $gbaDest) {
        Remove-Item -LiteralPath $gbaDest -Recurse -Force
    }
    if (Test-Path -LiteralPath $hu2Dest) {
        Remove-Item -LiteralPath $hu2Dest -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $gbaDest | Out-Null

    $gbaCount = 0
    foreach ($gameRoot in @("dbzlog", "dbzlog2", "dbzbuusfury")) {
        $source = Join-Path $GbaTemp $gameRoot
        $destination = Join-Path $gbaDest $gameRoot
        $gbaCount += Copy-TreeFiltered -Source $source -Destination $destination -Extensions @(".png")
    }

    $hu2DevSource = Join-Path $Hu2Temp "HeroesUnited2Dev-master\Icons"
    $hu2Count = Copy-TreeFiltered -Source $hu2DevSource -Destination $hu2Dest -Extensions @(".dmi", ".png")

    $gbaReadme = @"
# Dragon Ball GBA sprite reference library

Imported from the user-provided `dragonballgba.rar` archive.

Contents are preserved by original game/source folder:
- `dbzlog/` — Dragon Ball Z: The Legacy of Goku
- `dbzlog2/` — Dragon Ball Z: The Legacy of Goku II
- `dbzbuusfury/` — Dragon Ball Z: Buu's Fury

Imported files: $gbaCount PNG sprite/background/reference sheets.

These assets are kept under `assets/vendor/` as source/reference material so gameplay code can selectively integrate individual sprites without modifying the originals.
"@
    Set-Content -LiteralPath (Join-Path $gbaDest "README.md") -Value $gbaReadme -Encoding UTF8

    $hu2Root = Join-Path $RepoRoot "assets\vendor\hu2_dev"
    $hu2Readme = @"
# Heroes United 2 Dev sprite reference library

Imported from the `HeroesUnited2Dev-master/Icons` tree contained in the user-provided `DBSL.rar` archive.

The `HeroesUnited2-master/Icons` tree is intentionally not duplicated here because the repository already mirrors that version under `assets/vendor/hu2/Icons`.

Imported files: $hu2Count `.dmi` / `.png` assets.
"@
    Set-Content -LiteralPath (Join-Path $hu2Root "README.md") -Value $hu2Readme -Encoding UTF8

    Write-Host "`n==> Importacao concluida" -ForegroundColor Green
    Write-Host "GBA PNGs: $gbaCount"
    Write-Host "HU2 Dev assets: $hu2Count"

    if ($gbaCount -ne 270) {
        Write-Warning "Esperava 270 PNGs GBA, mas foram importados $gbaCount. Confira o arquivo de origem."
    }
    if ($hu2Count -ne 292) {
        Write-Warning "Esperava 292 assets HU2 Dev, mas foram importados $hu2Count. Confira o arquivo de origem."
    }

    git status --short -- "assets/vendor/dragon_ball_gba" "assets/vendor/hu2_dev" | Out-Host

    Write-Host "`n==> Adicionando sprites ao Git..." -ForegroundColor Yellow
    git add -- "assets/vendor/dragon_ball_gba" "assets/vendor/hu2_dev"
    if ($LASTEXITCODE -ne 0) { throw "git add falhou." }

    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Nenhuma alteracao nova para commitar." -ForegroundColor Green
        return
    }

    git commit -m "assets: import complete LoG Buu Fury and HU2 Dev sprite library"
    if ($LASTEXITCODE -ne 0) { throw "git commit falhou." }

    if (-not $NoPush) {
        Write-Host "`n==> Enviando para origin/$Branch..." -ForegroundColor Yellow
        git push origin "HEAD:$Branch"
        if ($LASTEXITCODE -ne 0) { throw "git push falhou." }
        Write-Host "Sprites enviados ao GitHub com sucesso." -ForegroundColor Green
    }
    else {
        Write-Host "Commit criado. Push ignorado por -NoPush." -ForegroundColor Yellow
    }
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
