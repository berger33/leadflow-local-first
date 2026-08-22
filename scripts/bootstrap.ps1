param(
    [switch]$NoOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & docker compose @Args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Args -join ' ') falhou com codigo $LASTEXITCODE."
    }
}

function Get-EnvMap {
    $map = @{}
    if (-not (Test-Path '.env')) { return $map }
    foreach ($line in Get-Content '.env') {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#') -or -not $trimmed.Contains('=')) { continue }
        $parts = $trimmed.Split('=', 2)
        $map[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $map
}

function Set-EnvValue([string]$Key, [string]$Value) {
    $lines = @(Get-Content '.env')
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^' + [regex]::Escape($Key) + '=')) {
            $lines[$i] = "$Key=$Value"
            $found = $true
            break
        }
    }
    if (-not $found) { $lines += "$Key=$Value" }
    [IO.File]::WriteAllLines((Resolve-Path '.env'), $lines, (New-Object Text.UTF8Encoding($false)))
}

function New-Secret([int]$Length = 64) {
    $value = ''
    while ($value.Length -lt $Length) {
        $value += [guid]::NewGuid().ToString('N')
    }
    return $value.Substring(0, $Length)
}

function Ensure-Environment {
    Write-Step 'Preparando configuracao local segura'
    if (-not (Test-Path '.env')) {
        Copy-Item '.env.example' '.env'
        Write-Ok '.env criado a partir de .env.example.'
    }

    $raw = Get-Content '.env' -Raw
    $replacements = @{
        'CHANGE_ME_STRONG_DATABASE_PASSWORD' = (New-Secret 64)
        'CHANGE_ME_64_CHARS_OR_MORE'          = (New-Secret 64)
        'CHANGE_ME_32_CHARS_OR_MORE'          = (New-Secret 64)
        'CHANGE_ME_STRONG_PASSWORD'           = (New-Secret 40)
    }
    $changed = $false
    foreach ($key in $replacements.Keys) {
        if ($raw.Contains($key)) {
            $raw = $raw.Replace($key, $replacements[$key])
            $changed = $true
        }
    }
    if ($changed) {
        [IO.File]::WriteAllText((Resolve-Path '.env'), $raw, (New-Object Text.UTF8Encoding($false)))
        Write-Ok 'Segredos locais ausentes foram gerados automaticamente.'
    }

    $envMap = Get-EnvMap
    $approval = if ($envMap.ContainsKey('APPROVAL_EMAIL')) { $envMap['APPROVAL_EMAIL'] } else { '' }
    if (-not $approval -or $approval -match '^seu-email@') {
        Write-Host ''
        Write-Host 'Acoes apagar_email e enviar_whatsapp usam aprovacao humana por e-mail.' -ForegroundColor Yellow
        do {
            $approval = Read-Host 'Informe o e-mail que recebera aprovacoes (ENTER para configurar depois)'
            if (-not $approval) { break }
            if ($approval -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
                Write-Warn 'Formato de e-mail invalido.'
                $approval = $null
            }
        } while ($null -eq $approval)
        Set-EnvValue 'APPROVAL_EMAIL' $approval
    }
}

function Remove-LegacyContainers {
    Write-Step 'Reparando containers legados de versoes anteriores'
    $legacyNames = @(
        'sistema-agentico-ollama-init',
        'sistema-agentico-ollama',
        'sistema-agentico-postgres',
        'sistema-agentico-n8n',
        'sistema-agentico-waha'
    )
    $existing = @(& docker ps -a --format '{{.Names}}')
    foreach ($name in $legacyNames) {
        if ($existing -contains $name) {
            Write-Host "Removendo container legado: $name"
            & docker rm -f $name | Out-Null
        }
    }
    Write-Ok 'Containers legados verificados. Volumes de dados nao foram apagados.'
}

function Wait-Http([string]$Url, [int]$Attempts = 60, [int]$DelaySeconds = 2) {
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) { return $true }
        } catch {
            Start-Sleep -Seconds $DelaySeconds
            continue
        }
        Start-Sleep -Seconds $DelaySeconds
    }
    return $false
}

function Wait-Postgres {
    for ($i = 1; $i -le 40; $i++) {
        & docker compose exec -T postgres pg_isready -U n8n -d n8n *> $null
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Ensure-OllamaModel([string]$Model) {
    if (-not $Model) { return }
    Write-Step "Verificando modelo Ollama: $Model"
    & docker compose exec -T ollama ollama show $Model *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Modelo $Model ja esta instalado."
        return
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "Baixando $Model (tentativa $attempt/3)..."
        & docker compose exec -T ollama ollama pull $Model
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Modelo $Model instalado."
            return
        }
        if ($attempt -lt 3) { Start-Sleep -Seconds 5 }
    }

    throw "Nao foi possivel baixar o modelo $Model apos 3 tentativas. Verifique internet, espaco em disco e os logs do Ollama."
}

function Import-WorkflowIfNeeded {
    Write-Step 'Verificando workflow n8n'
    $workflowName = 'Sistema Agêntico n8n WhatsApp+Email'
    $listed = (& docker compose exec -T n8n n8n list:workflow 2>&1 | Out-String)
    $listExit = $LASTEXITCODE

    if ($listExit -eq 0 -and $listed -like "*$workflowName*") {
        Write-Ok 'Workflow principal ja existe; importacao duplicada evitada.'
        return
    }

    & docker compose exec -T n8n n8n import:workflow --input=/files/n8n-agent-workflow.json
    if ($LASTEXITCODE -ne 0) {
        throw 'n8n iniciou, mas a importacao automatica do workflow falhou.'
    }
    Write-Ok 'Workflow principal importado.'
}

try {
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' Sistema Agentico n8n WhatsApp+Email - Bootstrap Inteligente' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor DarkCyan

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop nao foi encontrado. Instale o Docker Desktop e execute novamente.'
    }

    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop esta instalado, mas o Engine ainda nao esta pronto.'
    }
    Write-Ok 'Docker Engine disponivel.'

    Ensure-Environment

    Write-Step 'Validando docker-compose.yml e .env'
    & docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose encontrou uma configuracao invalida.' }
    Write-Ok 'Docker Compose valido.'

    Remove-LegacyContainers

    Write-Step 'Iniciando PostgreSQL e Ollama'
    Invoke-Compose up -d postgres ollama

    if (-not (Wait-Postgres)) {
        & docker compose logs --tail=80 postgres
        throw 'PostgreSQL nao ficou pronto dentro do tempo esperado.'
    }
    Write-Ok 'PostgreSQL pronto.'

    if (-not (Wait-Http 'http://127.0.0.1:11434/api/tags' 60 2)) {
        & docker compose logs --tail=100 ollama
        throw 'Ollama nao respondeu na porta 11434.'
    }
    Write-Ok 'Ollama pronto.'

    $envMap = Get-EnvMap
    $mainModel = if ($envMap.ContainsKey('OLLAMA_MODEL') -and $envMap['OLLAMA_MODEL']) { $envMap['OLLAMA_MODEL'] } else { 'qwen3:4b' }
    $validatorModel = if ($envMap.ContainsKey('OLLAMA_VALIDATOR_MODEL') -and $envMap['OLLAMA_VALIDATOR_MODEL']) { $envMap['OLLAMA_VALIDATOR_MODEL'] } else { $mainModel }
    Ensure-OllamaModel $mainModel
    if ($validatorModel -ne $mainModel) { Ensure-OllamaModel $validatorModel }

    Write-Step 'Iniciando n8n e WAHA'
    Invoke-Compose up -d n8n waha

    if (-not (Wait-Http 'http://127.0.0.1:5678/healthz' 90 2)) {
        & docker compose logs --tail=120 n8n
        throw 'n8n nao respondeu ao health check.'
    }
    Write-Ok 'n8n pronto.'

    if (Wait-Http 'http://127.0.0.1:3000/health' 60 2) {
        Write-Ok 'WAHA pronto.'
    } else {
        Write-Warn 'WAHA ainda nao respondeu ao health check. O n8n e o Ollama estao ativos; consulte o diagnostico se o dashboard nao abrir.'
    }

    Import-WorkflowIfNeeded

    Write-Step 'Estado final dos servicos'
    & docker compose ps

    if (-not $NoOpen) {
        Start-Process 'http://127.0.0.1:5678'
        Start-Process 'http://127.0.0.1:3000/dashboard'
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ' BOOTSTRAP CONCLUIDO' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host 'Configurado automaticamente: Docker, banco, segredos locais, Ollama, modelos, n8n, WAHA e importacao do workflow.'
    Write-Host ''
    Write-Host 'Acoes externas exigem apenas autorizacoes que nao podem ser fabricadas pelo instalador:' -ForegroundColor Yellow
    Write-Host '  1. n8n: crie o usuario administrador local na primeira abertura.'
    Write-Host '  2. Ollama no n8n: crie a credencial com Base URL http://ollama:11434 e associe aos 2 nos de modelo.'
    Write-Host '  3. Gmail/Calendar: autorize sua conta Google via OAuth2 nos respectivos nos.'
    Write-Host '  4. WhatsApp: abra o WAHA e escaneie o QR Code da sessao default.'
    Write-Host 'Essas etapas envolvem identidade/consentimento e por seguranca nao sao gravadas no GitHub.'
    exit 0
} catch {
    Write-Host ''
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Executando diagnostico resumido...' -ForegroundColor Yellow
    & docker compose ps 2>$null
    Write-Host ''
    Write-Host 'Para detalhes, execute DIAGNOSTICO_WINDOWS.bat.' -ForegroundColor Yellow
    exit 1
}
