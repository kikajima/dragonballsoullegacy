param(
    [switch]$SkipPull,
    [switch]$OpenEditor
)

$ErrorActionPreference = "Stop"

$ProjectPath = "E:\jogos feitos com ia\DBSL\dragon-ball-soul-legacy-git"
$Branch = "develop"
$LogPath = "E:\jogos feitos com ia\DBSL\godot-test.log"
$GodotDir = Join-Path $env:USERPROFILE "Tools\Godot"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERRO: $Message" -ForegroundColor Red
    exit 1
}

Write-Step "Validando ambiente"

if (-not (Test-Path $ProjectPath)) {
    Fail "Projeto nao encontrado em: $ProjectPath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git nao foi encontrado no PATH."
}

if (-not (Test-Path $GodotDir)) {
    Fail "Pasta do Godot nao encontrada em: $GodotDir"
}

# Prefere exatamente o console da 4.7.2, mas aceita outra versao estavel
# encontrada na mesma pasta caso o nome seja diferente.
$PreferredGodot = Join-Path $GodotDir "Godot_v4.7.2-stable_win64_console.exe"

if (Test-Path $PreferredGodot) {
    $GodotExe = $PreferredGodot
}
else {
    $GodotExe = Get-ChildItem -Path $GodotDir `
        -Filter "Godot_v*-stable_win64_console.exe" `
        -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $GodotExe) {
    Fail "Executavel console do Godot nao encontrado em: $GodotDir"
}

Write-Host "Projeto : $ProjectPath"
Write-Host "Branch  : $Branch"
Write-Host "Godot   : $GodotExe"
Write-Host "Log     : $LogPath"

Push-Location $ProjectPath

try {
    if (-not $SkipPull) {
        Write-Step "Verificando alteracoes locais"

        $LocalChanges = git status --porcelain

        if ($LASTEXITCODE -ne 0) {
            Fail "Nao foi possivel consultar o status do repositorio Git."
        }

        if ($LocalChanges) {
            Write-Host ""
            Write-Host "Existem alteracoes locais no repositorio." -ForegroundColor Yellow
            Write-Host "Para evitar perda de trabalho, o script NAO fara checkout nem pull." -ForegroundColor Yellow
            Write-Host ""
            git status --short
            Write-Host ""
            Write-Host "Resolva/commite/stash essas alteracoes e execute novamente." -ForegroundColor Yellow
            Write-Host "Ou rode com -SkipPull para testar exatamente os arquivos locais:"
            Write-Host '  .\test-game.ps1 -SkipPull'
            exit 2
        }

        Write-Step "Atualizando branch $Branch"

        git fetch origin $Branch
        if ($LASTEXITCODE -ne 0) {
            Fail "git fetch falhou."
        }

        git checkout $Branch
        if ($LASTEXITCODE -ne 0) {
            Fail "Nao foi possivel mudar para a branch $Branch."
        }

        git pull --ff-only origin $Branch
        if ($LASTEXITCODE -ne 0) {
            Fail "git pull --ff-only falhou. O historico local pode ter divergido do remoto."
        }
    }
    else {
        Write-Step "Pull ignorado (-SkipPull)"
        Write-Host "Testando o estado local atual do projeto."
    }

    Write-Step "Versao do Godot"
    & $GodotExe --version

    Write-Step "Executando validacao headless"

    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }

    & $GodotExe `
        --headless `
        --path $ProjectPath `
        --editor `
        --quit 2>&1 |
        Tee-Object -FilePath $LogPath

    $GodotExitCode = $LASTEXITCODE

    Write-Step "Resumo"

    $ErrorPatterns = @(
        "SCRIPT ERROR",
        "Parse Error",
        "ERROR:",
        "FATAL:",
        "Failed loading",
        "Cannot open",
        "Invalid call",
        "Invalid access"
    )

    $Matches = Select-String `
        -Path $LogPath `
        -Pattern $ErrorPatterns `
        -SimpleMatch `
        -ErrorAction SilentlyContinue

    if ($Matches) {
        Write-Host ""
        Write-Host "Foram encontradas mensagens que merecem verificacao:" -ForegroundColor Yellow
        Write-Host ""

        $Matches |
            Select-Object -First 40 |
            ForEach-Object {
                Write-Host ("{0}: {1}" -f $_.LineNumber, $_.Line)
            }

        if ($Matches.Count -gt 40) {
            Write-Host ""
            Write-Host "... e mais $($Matches.Count - 40) ocorrencias. Veja o log completo."
        }
    }
    else {
        Write-Host "Nenhum erro conhecido foi encontrado no log." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Log completo salvo em:"
    Write-Host "  $LogPath"

    if ($GodotExitCode -ne 0) {
        Write-Host ""
        Write-Host "O Godot terminou com codigo de saida $GodotExitCode." -ForegroundColor Red
        exit $GodotExitCode
    }

    Write-Host ""
    Write-Host "Validacao concluida." -ForegroundColor Green

    if ($OpenEditor) {
        Write-Step "Abrindo editor"

        $EditorExe = $GodotExe -replace "_console\.exe$", ".exe"

        if (Test-Path $EditorExe) {
            Start-Process -FilePath $EditorExe -ArgumentList @(
                "--editor",
                "--path",
                $ProjectPath
            )
        }
        else {
            Write-Host "Executavel grafico nao encontrado: $EditorExe" -ForegroundColor Yellow
        }
    }
}
finally {
    Pop-Location
}
