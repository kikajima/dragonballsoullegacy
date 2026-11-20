param(
    [ValidateSet('log1', 'log2', 'buu')]
    [string]$Game = 'buu',
    [switch]$FromBattery
)
$ErrorActionPreference = 'Stop'
$referenceRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'references/roms'
$emulatorPath = Join-Path $referenceRoot 'visualboyadvance-m.exe'
$gameNames = @{
    log1 = 'Dragon Ball Z - The Legacy of Goku (USA)'
    log2 = 'Dragon Ball Z - The Legacy of Goku II (USA)'
    buu = "Dragon Ball Z - Buu's Fury (USA)"
}
$romPath = Join-Path $referenceRoot ($gameNames[$Game] + '.gba')
if (!(Test-Path -LiteralPath $emulatorPath) -or !(Test-Path -LiteralPath $romPath)) {
    throw 'Emulador ou ROM ausente em references/roms.'
}
$sessionPath = Join-Path $referenceRoot 'analysis/vba-session'
New-Item -ItemType Directory -Force $sessionPath | Out-Null
$saveName = $gameNames[$Game] + '.sav'
$preparedSave = Join-Path (Join-Path $referenceRoot 'prepared') $saveName
$sessionSave = Join-Path $sessionPath $saveName
if ((Test-Path -LiteralPath $preparedSave) -and !(Test-Path -LiteralPath $sessionSave)) {
    Copy-Item -LiteralPath $preparedSave -Destination $sessionSave
}
$configPath = Join-Path $sessionPath 'vbam.ini'
if (!(Test-Path -LiteralPath $configPath)) {
    New-Item -ItemType File -Path $configPath | Out-Null
}
$autoLoad = if ($FromBattery) { '0' } else { '1' }
& $emulatorPath "--config=$configPath" $romPath `
    "General/BatteryDir=$sessionPath" "General/StateDir=$sessionPath" `
    "General/ScreenshotDir=$sessionPath" "General/AutoLoadLastState=$autoLoad" `
    'ui/hideMenuBar=0' 'preferences/pauseWhenInactive=1' `
    'Display/RenderMethod=simple' 'Display/Scale=3' 'Sound/Volume=0' `
    'Joypad/1/Up=W' 'Joypad/1/Down=S' 'Joypad/1/Left=A' 'Joypad/1/Right=D' `
    'Joypad/1/A=L' 'Joypad/1/B=K' 'Joypad/1/L=I' 'Joypad/1/R=O' `
    'Joypad/1/Start=ENTER' 'Joypad/1/Select=BACK'
