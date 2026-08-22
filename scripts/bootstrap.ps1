param(
    [ValidateSet('Full','Prepare','Finalize','Start')]
    [string]$Mode = 'Full',
    [switch]$NoOpen,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeCredentialFile = Join-Path $ProjectRoot 'setup\credentials.runtime.json'
$RuntimeWorkflowFile = Join-Path $ProjectRoot 'setup\workflow.runtime.json'
Set-Location $ProjectRoot

$OllamaCredentialId = '11111111-aaaa-4aaa-8aaa-111111111111'
$GmailCredentialId = '22222222-bbbb-4bbb-8bbb-222222222222'
$CalendarCredentialId = '33333333-cccc-4ccc-8ccc-333333333333'

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[AVISO] $Message" -ForegroundColor Yellow }

function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop nao foi encontrado. Instale o Docker Desktop e tente novamente.'
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop esta instalado, mas o Engine ainda nao esta pronto.'
    }
    Write-Ok 'Docker Engine disponivel.'
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
    if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }
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
    while ($value.Length -lt $Length) { $value += [guid]::NewGuid().ToString('N') }
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
        Write-Ok 'Segredos internos ausentes foram gerados automaticamente.'
    }

    if ($Mode -eq 'Full' -and -not $NonInteractive) {
        $envMap = Get-EnvMap
        $approval = if ($envMap.ContainsKey('APPROVAL_EMAIL')) { $envMap['APPROVAL_EMAIL'] } else { '' }
        if (-not $approval) {
            Write-Host ''
            Write-Host 'Acoes apagar_email e enviar_whatsapp usam aprovacao humana por e-mail.' -ForegroundColor Yellow
            $approval = Read-Host 'Informe o e-mail de aprovacao (ENTER para configurar depois)'
            if ($approval) { Set-EnvValue 'APPROVAL_EMAIL' $approval }
        }
    }
}

function Remove-LegacyContainers {
    Write-Step 'Verificando restos de versoes anteriores'
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
    Write-Ok 'Containers legados verificados; volumes persistentes foram preservados.'
}

function Wait-Http([string]$Url, [int]$Attempts = 60, [int]$DelaySeconds = 2) {
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { return $true }
        } catch {}
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
    throw "Nao foi possivel baixar/validar o modelo $Model apos 3 tentativas."
}

function Test-N8nNeedsOwner {
    try {
        $settings = Invoke-RestMethod -Uri 'http://127.0.0.1:5678/rest/settings' -Method Get -TimeoutSec 8
        if ($null -eq $settings -or $null -eq $settings.data -or $null -eq $settings.data.userManagement) { return $false }
        return [bool]$settings.data.userManagement.showSetupOnFirstLoad
    } catch { return $false }
}

function Ensure-N8nOwnerInteractive {
    if (-not (Test-N8nNeedsOwner)) {
        Write-Ok 'Proprietario local do n8n ja configurado.'
        return
    }
    if ($NonInteractive) {
        Write-Host '[STATE] N8N_OWNER_REQUIRED'
        exit 20
    }

    Write-Warn 'O n8n precisa criar o primeiro usuario local uma unica vez.'
    Start-Process 'http://127.0.0.1:5678'
    Read-Host 'Conclua o cadastro no navegador e pressione ENTER para continuar' | Out-Null
    for ($i = 1; $i -le 30; $i++) {
        if (-not (Test-N8nNeedsOwner)) { Write-Ok 'Proprietario local confirmado.'; return }
        Start-Sleep -Seconds 2
    }
    throw 'O cadastro inicial do n8n ainda nao foi concluido.'
}

function Add-CredentialReference($Node, [string]$CredentialType, [string]$CredentialId, [string]$CredentialName) {
    $credentialMap = [ordered]@{}
    $credentialMap[$CredentialType] = [ordered]@{ id = $CredentialId; name = $CredentialName }
    $Node | Add-Member -NotePropertyName credentials -NotePropertyValue ([pscustomobject]$credentialMap) -Force
}

function Prepare-N8nRuntimeFiles {
    Write-Step 'Preparando conexoes locais do n8n'
    $envMap = Get-EnvMap
    $googleClientId = if ($envMap.ContainsKey('GOOGLE_CLIENT_ID')) { $envMap['GOOGLE_CLIENT_ID'] } else { '' }
    $googleClientSecret = if ($envMap.ContainsKey('GOOGLE_CLIENT_SECRET')) { $envMap['GOOGLE_CLIENT_SECRET'] } else { '' }
    $hasGoogle = [bool]($googleClientId -and $googleClientSecret)

    $credentials = @()
    $credentials += [pscustomobject][ordered]@{
        id = $OllamaCredentialId
        name = 'Ollama Local - Sistema Agentico'
        type = 'ollamaApi'
        data = [ordered]@{ baseUrl = 'http://ollama:11434'; apiKey = '' }
    }

    if ($hasGoogle) {
        $gmailScope = 'https://www.googleapis.com/auth/gmail.labels https://www.googleapis.com/auth/gmail.addons.current.action.compose https://www.googleapis.com/auth/gmail.addons.current.message.action https://mail.google.com/ https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/gmail.compose'
        $calendarScope = 'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events'
        $common = [ordered]@{
            grantType = 'authorizationCode'
            authUrl = 'https://accounts.google.com/o/oauth2/v2/auth'
            accessTokenUrl = 'https://oauth2.googleapis.com/token'
            clientId = $googleClientId
            clientSecret = $googleClientSecret
            authQueryParameters = 'access_type=offline&prompt=consent'
            authentication = 'body'
        }
        $gmailData = [ordered]@{}
        foreach ($k in $common.Keys) { $gmailData[$k] = $common[$k] }
        $gmailData['customScopes'] = $false
        $gmailData['scope'] = $gmailScope
        $calendarData = [ordered]@{}
        foreach ($k in $common.Keys) { $calendarData[$k] = $common[$k] }
        $calendarData['customScopes'] = $false
        $calendarData['scope'] = $calendarScope

        $credentials += [pscustomobject][ordered]@{ id=$GmailCredentialId; name='Gmail - Sistema Agentico'; type='gmailOAuth2'; data=$gmailData }
        $credentials += [pscustomobject][ordered]@{ id=$CalendarCredentialId; name='Google Calendar - Sistema Agentico'; type='googleCalendarOAuth2Api'; data=$calendarData }
    }

    $credentialsJson = ConvertTo-Json -InputObject @($credentials) -Depth 20
    [IO.File]::WriteAllText($RuntimeCredentialFile, $credentialsJson, (New-Object Text.UTF8Encoding($false)))

    $workflow = Get-Content 'n8n-agent-workflow.json' -Raw | ConvertFrom-Json
    foreach ($node in $workflow.nodes) {
        if ($node.name -in @('Ollama · Modelo Executor','Ollama · Modelo Validador')) {
            Add-CredentialReference $node 'ollamaApi' $OllamaCredentialId 'Ollama Local - Sistema Agentico'
        }
        if ($hasGoogle -and $node.name -in @('ler_email','resumir_email','Solicitar aprovação · apagar_email','Gmail · Apagar Email','Solicitar aprovação · enviar_whatsapp')) {
            Add-CredentialReference $node 'gmailOAuth2' $GmailCredentialId 'Gmail - Sistema Agentico'
        }
        if ($hasGoogle -and $node.name -eq 'criar_evento') {
            Add-CredentialReference $node 'googleCalendarOAuth2Api' $CalendarCredentialId 'Google Calendar - Sistema Agentico'
        }
    }
    $workflowJson = $workflow | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($RuntimeWorkflowFile, $workflowJson, (New-Object Text.UTF8Encoding($false)))

    if ($hasGoogle) { Write-Ok 'Ollama, Gmail e Calendar preparados para importacao.' }
    else { Write-Ok 'Ollama preparado automaticamente. Google sera conectado depois pelo usuario.' }
    return $hasGoogle
}

function Import-LocalCredentials {
    $hasGoogle = Prepare-N8nRuntimeFiles
    $output = (& docker compose exec -T n8n n8n import:credentials --input=/files/setup/credentials.runtime.json 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        Write-Host $output
        if ($output -match 'Failed to find owner') { Write-Host '[STATE] N8N_OWNER_REQUIRED'; exit 20 }
        throw 'Falha ao importar as conexoes locais do n8n.'
    }
    Write-Ok 'Credencial Ollama criada automaticamente no n8n.'
    if ($hasGoogle) { Write-Ok 'Credenciais Google preparadas; falta apenas consentir via OAuth no navegador.' }
}

function Import-WorkflowIfNeeded {
    Write-Step 'Verificando workflow n8n'
    $workflowName = 'Sistema Agêntico n8n WhatsApp+Email'
    $listed = (& docker compose exec -T n8n n8n list:workflow 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -and $listed -like "*$workflowName*") {
        Write-Warn 'Workflow principal ja existe; duplicacao evitada. Conexoes locais foram atualizadas separadamente.'
        return
    }

    $importOutput = (& docker compose exec -T n8n n8n import:workflow --input=/files/setup/workflow.runtime.json 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        Write-Host $importOutput
        if ($importOutput -match 'Failed to find owner') { Write-Host '[STATE] N8N_OWNER_REQUIRED'; exit 20 }
        throw 'A importacao automatica do workflow falhou.'
    }

    $verified = (& docker compose exec -T n8n n8n list:workflow 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $verified -notlike "*$workflowName*") {
        throw 'O workflow nao apareceu na verificacao apos a importacao.'
    }
    Write-Ok 'Workflow principal importado e verificado.'
}

function Cleanup-RuntimeFiles {
    Remove-Item $RuntimeCredentialFile -Force -ErrorAction SilentlyContinue
    Remove-Item $RuntimeWorkflowFile -Force -ErrorAction SilentlyContinue
}

function Prepare-Core {
    Assert-Docker
    Ensure-Environment

    Write-Step 'Validando Docker Compose'
    & docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose encontrou configuracao invalida.' }
    Write-Ok 'Docker Compose valido.'

    Remove-LegacyContainers
    $envMap = Get-EnvMap
    $pgUser = if ($envMap.ContainsKey('POSTGRES_USER') -and $envMap['POSTGRES_USER']) { $envMap['POSTGRES_USER'] } else { 'n8n' }
    $pgDatabase = if ($envMap.ContainsKey('POSTGRES_DB') -and $envMap['POSTGRES_DB']) { $envMap['POSTGRES_DB'] } else { 'n8n' }
    $mainModel = if ($envMap.ContainsKey('OLLAMA_MODEL') -and $envMap['OLLAMA_MODEL']) { $envMap['OLLAMA_MODEL'] } else { 'qwen3:4b' }
    $validatorModel = if ($envMap.ContainsKey('OLLAMA_VALIDATOR_MODEL') -and $envMap['OLLAMA_VALIDATOR_MODEL']) { $envMap['OLLAMA_VALIDATOR_MODEL'] } else { $mainModel }

    Write-Step 'Iniciando PostgreSQL e Ollama'
    & docker compose up -d postgres ollama
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar PostgreSQL/Ollama.' }

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

    Ensure-OllamaModel $mainModel
    if ($validatorModel -ne $mainModel) { Ensure-OllamaModel $validatorModel }

    Write-Step 'Iniciando n8n e WAHA'
    & docker compose up -d n8n waha
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar n8n/WAHA.' }

    if (-not (Wait-Http 'http://127.0.0.1:5678/healthz' 90 2)) {
        & docker compose logs --tail=120 n8n
        throw 'n8n nao respondeu ao health check.'
    }
    Write-Ok 'n8n pronto.'

    if (-not (Wait-Http 'http://127.0.0.1:3000/health' 60 2)) {
        & docker compose logs --tail=100 waha
        throw 'WAHA nao respondeu ao health check.'
    }
    Write-Ok 'WAHA pronto.'
    Write-Host '[STATE] INFRA_READY'
}

function Finalize-Core {
    Assert-Docker
    if (-not (Wait-Http 'http://127.0.0.1:5678/healthz' 10 1)) { throw 'n8n nao esta disponivel. Execute a fase Prepare primeiro.' }
    if (-not (Wait-Http 'http://127.0.0.1:3000/health' 10 1)) { throw 'WAHA nao esta disponivel. Execute a fase Prepare primeiro.' }
    if (Test-N8nNeedsOwner) {
        if ($NonInteractive) { Write-Host '[STATE] N8N_OWNER_REQUIRED'; exit 20 }
        Ensure-N8nOwnerInteractive
    }
    try {
        Import-LocalCredentials
        Import-WorkflowIfNeeded
        [IO.File]::WriteAllText((Join-Path $ProjectRoot '.setup-complete'), (Get-Date).ToString('o'), (New-Object Text.UTF8Encoding($false)))
        Write-Host '[STATE] SETUP_COMPLETE'
    } finally {
        Cleanup-RuntimeFiles
    }
}

function Start-Existing {
    Assert-Docker
    Ensure-Environment
    & docker compose up -d postgres ollama n8n waha
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o stack existente.' }
    if (-not (Wait-Http 'http://127.0.0.1:5678/healthz' 60 2)) { throw 'n8n nao ficou pronto.' }
    if (-not (Wait-Http 'http://127.0.0.1:11434/api/tags' 60 2)) { throw 'Ollama nao ficou pronto.' }
    if (-not (Wait-Http 'http://127.0.0.1:3000/health' 60 2)) { throw 'WAHA nao ficou pronto.' }
    Write-Host '[STATE] STACK_READY'
}

function Show-LocalAccess {
    $envMap = Get-EnvMap
    $user = if ($envMap.ContainsKey('WAHA_DASHBOARD_USERNAME')) { $envMap['WAHA_DASHBOARD_USERNAME'] } else { 'admin' }
    $password = if ($envMap.ContainsKey('WAHA_DASHBOARD_PASSWORD')) { $envMap['WAHA_DASHBOARD_PASSWORD'] } else { '' }
    Write-Host ''
    Write-Host 'Acessos locais:' -ForegroundColor Cyan
    Write-Host '  n8n: http://127.0.0.1:5678'
    Write-Host '  WAHA: http://127.0.0.1:3000/dashboard'
    Write-Host "  Usuario WAHA: $user"
    if ($password) { Write-Host "  Senha WAHA: $password" }
}

try {
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host " Sistema Agentico - Bootstrap ($Mode)" -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor DarkCyan

    switch ($Mode) {
        'Prepare' { Prepare-Core }
        'Finalize' { Finalize-Core }
        'Start' { Start-Existing }
        'Full' {
            Prepare-Core
            Ensure-N8nOwnerInteractive
            try {
                Import-LocalCredentials
                Import-WorkflowIfNeeded
                [IO.File]::WriteAllText((Join-Path $ProjectRoot '.setup-complete'), (Get-Date).ToString('o'), (New-Object Text.UTF8Encoding($false)))
                Write-Host '[STATE] SETUP_COMPLETE'
            } finally { Cleanup-RuntimeFiles }
        }
    }

    if ($Mode -in @('Full','Finalize','Start')) { Show-LocalAccess }
    if (-not $NoOpen -and $Mode -in @('Full','Finalize','Start')) {
        Start-Process 'http://127.0.0.1:5678'
        Start-Process 'http://127.0.0.1:3000/dashboard'
    }
    exit 0
} catch {
    Cleanup-RuntimeFiles
    Write-Host ''
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    if (Get-Command docker -ErrorAction SilentlyContinue) { & docker compose ps 2>$null }
    Write-Host 'Execute DIAGNOSTICO_WINDOWS.bat para detalhes.' -ForegroundColor Yellow
    exit 1
}
