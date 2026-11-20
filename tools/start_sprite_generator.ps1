param(
    [string]$GodotPath,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$scene = 'res://tools/sprite_generator/sprite_generator.tscn'
$candidates = @()
if ($GodotPath) { $candidates += $GodotPath }
$metadataPath = Join-Path $projectRoot '.godot/editor/project_metadata.cfg'
if (Test-Path -LiteralPath $metadataPath) {
    $metadataText = Get-Content -LiteralPath $metadataPath -Raw
    if ($metadataText -match 'executable_path="([^"]+)"') { $candidates += $Matches[1] }
}
$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
if ($godotCommand) { $candidates += $godotCommand.Source }
$candidates += (Join-Path $env:USERPROFILE 'Tools/Godot/Godot_v4.7.2-stable_win64_console.exe')
$executable = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $executable) {
    throw 'Godot nao encontrado. Execute tools/start_sprite_generator.ps1 -GodotPath "C:\caminho\Godot.exe"'
}
Write-Host "Abrindo a oficina de sprites: $scene"
$launchArguments = @('--path', $projectRoot, $scene)
if ($SmokeTest) { $launchArguments += @('--headless', '--quit-after', '10') }
& $executable @launchArguments | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Godot terminou com erro $LASTEXITCODE" }
