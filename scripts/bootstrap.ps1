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
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { return $true }
        } catch {
            Start-Sleep -Seconds $DelaySeconds
            continue
        }
        Start-Sleep -Seconds $DelaySeconds
    }
    return $false
}

function Wait-Postgres([string]$User, [string]$Database) {
    for ($i = 1; $i -le 40; $i++) {
        & docker compose exec -T postgres pg_isready -U $User -d $Database *> $null
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
            & docker compose exec -T ollama ollama show $Model *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Modelo $Model instalado e validado."
                return
            }
        }
        if ($attempt -lt 3) { Start-Sleep -Seconds 5 }
    }

    throw "Nao foi possivel baixar/validar o modelo $Model apos 3 tentativas. Verifique internet, espaco em disco e os logs do Ollama."
}

function Test-N8nNeedsOwner {
    try {
        $settings = Invoke-RestMethod -Uri 'http://127.0.0.1:5678/rest/settings' -Method Get -TimeoutSec 8
        if ($null -eq $settings -or $null -eq $settings.data -or $null -eq $settings.data.userManagement) {
            return $false
        }
        return [bool]$settings.data.userManagement.showSetupOnFirstLoad
    } catch {
        return $false
    }
}

function Ensure-N8nOwner {
    Write-Step 'Verificando cadastro local do n8n'
    if (-not (Test-N8nNeedsOwner)) {
        Write-Ok 'Proprietario local do n8n ja configurado.'
        return
    }

    Write-Warn 'Esta e uma instalacao nova do n8n. O primeiro proprietario local precisa ser criado uma unica vez.'
    Write-Host 'Nenhuma chave externa e solicitada nesta etapa; trata-se apenas do login local do seu n8n.'
    Start-Process 'http://127.0.0.1:5678'
    Write-Host ''
    Read-Host 'Conclua o cadastro do proprietario na pagina que abriu e pressione ENTER aqui para continuar' | Out-Null

    for ($i = 1; $i -le 30; $i++) {
        if (-not (Test-N8nNeedsOwner)) {
            Write-Ok 'Proprietario local do n8n confirmado.'
            return
        }
        Start-Sleep -Seconds 2
    }

    throw 'O cadastro inicial do n8n ainda nao foi concluido. Finalize o formulario aberto no navegador e execute novamente.'
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

    $importOutput = (& docker compose exec -T n8n n8n import:workflow --input=/files/n8n-agent-workflow.json 2>&1 | Out-String)
    $importExit = $LASTEXITCODE
    if ($importExit -ne 0) {
        Write-Host $importOutput
        if ($importOutput -match 'Failed to find owner') {
            throw 'O n8n ainda nao possui proprietario local. Conclua o cadastro inicial e execute novamente.'
        }
        throw 'n8n iniciou, mas a importacao automatica do workflow falhou. Consulte a mensagem acima.'
    }

    $verified = (& docker compose exec -T n8n n8n list:workflow 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $verified -notlike "*$workflowName*") {
        throw 'A CLI informou importacao concluida, mas o workflow nao apareceu na verificacao final.'
    }
    Write-Ok 'Workflow principal importado e verificado.'
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

    $envMap = Get-EnvMap
    $pgUser = if ($envMap.ContainsKey('POSTGRES_USER') -and $envMap['POSTGRES_USER']) { $envMap['POSTGRES_USER'] } else { 'n8n' }
    $pgDatabase = if ($envMap.ContainsKey('POSTGRES_DB') -and $envMap['POSTGRES_DB']) { $envMap['POSTGRES_DB'] } else { 'n8n' }

    Write-Step 'Iniciando PostgreSQL e Ollama'
    & docker compose up -d postgres ollama
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao iniciar PostgreSQL/Ollama. Execute DIAGNOSTICO_WINDOWS.bat para detalhes.'
    }

    if (-not (Wait-Postgres $pgUser $pgDatabase)) {
        & docker compose logs --tail=80 postgres
        throw 'PostgreSQL nao ficou pronto dentro do tempo esperado.'
    }
    Write-Ok 'PostgreSQL pronto.'

    if (-not (Wait-Http 'http://127.0.0.1:11434/api/tags' 60 2)) {
        & docker compose logs --tail=100 ollama
        throw 'Ollama nao respondeu na porta 11434.'
    }
    Write-Ok 'Ollama pronto.'

    $mainModel = if ($envMap.ContainsKey('OLLAMA_MODEL') -and $envMap['OLLAMA_MODEL']) { $envMap['OLLAMA_MODEL'] } else { 'qwen3:4b' }
    $validatorModel = if ($envMap.ContainsKey('OLLAMA_VALIDATOR_MODEL') -and $envMap['OLLAMA_VALIDATOR_MODEL']) { $envMap['OLLAMA_VALIDATOR_MODEL'] } else { $mainModel }
    Ensure-OllamaModel $mainModel
    if ($validatorModel -ne $mainModel) { Ensure-OllamaModel $validatorModel }

    Write-Step 'Iniciando n8n e WAHA'
    & docker compose up -d n8n waha
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao iniciar n8n/WAHA. Execute DIAGNOSTICO_WINDOWS.bat para detalhes.'
    }

    if (-not (Wait-Http 'http://127.0.0.1:5678/healthz' 90 2)) {
        & docker compose logs --tail=120 n8n
        throw 'n8n nao respondeu ao health check.'
    }
    Write-Ok 'n8n pronto.'

    if (-not (Wait-Http 'http://127.0.0.1:3000/health' 60 2)) {
        & docker compose logs --tail=100 waha
        throw 'WAHA nao respondeu ao health check. O bootstrap foi interrompido para nao reportar sucesso parcial.'
    }
    Write-Ok 'WAHA pronto.'

    Ensure-N8nOwner
    Import-WorkflowIfNeeded

    Write-Step 'Estado final dos servicos'
    & docker compose ps

    $finalEnv = Get-EnvMap

    if (-not $NoOpen) {
        Start-Process 'http://127.0.0.1:5678'
        Start-Process 'http://127.0.0.1:3000/dashboard'
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ' BOOTSTRAP CONCLUIDO' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host 'Validado: PostgreSQL, Ollama, modelo local, n8n, WAHA e workflow importado.'
    Write-Host 'Segredos internos foram gerados automaticamente quando necessario.'
    Write-Host ''
    Write-Host 'Acesso local ao WAHA:' -ForegroundColor Cyan
    Write-Host '  URL:     http://127.0.0.1:3000/dashboard'
    Write-Host ("  Usuario: " + $finalEnv['WAHA_DASHBOARD_USERNAME'])
    Write-Host ("  Senha:   " + $finalEnv['WAHA_DASHBOARD_PASSWORD'])
    Write-Host '  A senha aparece somente no seu terminal/.env local e nao e enviada ao GitHub.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Restam apenas integracoes vinculadas a identidade/consentimento do usuario:' -ForegroundColor Yellow
    Write-Host '  1. No workflow, crie a conexao Ollama API com Base URL http://ollama:11434 e associe aos 2 nos de modelo.'
    Write-Host '  2. Gmail/Calendar: autorize sua conta Google via OAuth2 nos respectivos nos.'
    Write-Host '  3. WhatsApp: abra o WAHA e escaneie o QR Code da sessao default.'
    Write-Host 'O instalador nunca salva tokens Google, cookies ou QR Codes no GitHub.'
    exit 0
} catch {
    Write-Host ''
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Executando diagnostico resumido...' -ForegroundColor Yellow
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        & docker compose ps 2>$null
    }
    Write-Host ''
    Write-Host 'Para detalhes, execute DIAGNOSTICO_WINDOWS.bat.' -ForegroundColor Yellow
    exit 1
}
