param(
    [int]$Port = 8765
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$UiFile = Join-Path $ProjectRoot 'setup\index.html'
$Bootstrap = Join-Path $PSScriptRoot 'bootstrap.ps1'
Set-Location $ProjectRoot

function New-Secret([int]$Length = 64) {
    $value = ''
    while ($value.Length -lt $Length) { $value += [guid]::NewGuid().ToString('N') }
    return $value.Substring(0, $Length)
}

function Ensure-EnvFile {
    if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }
    $raw = Get-Content '.env' -Raw
    $replacements = @{
        'CHANGE_ME_STRONG_DATABASE_PASSWORD' = (New-Secret 64)
        'CHANGE_ME_64_CHARS_OR_MORE'          = (New-Secret 64)
        'CHANGE_ME_32_CHARS_OR_MORE'          = (New-Secret 64)
        'CHANGE_ME_STRONG_PASSWORD'           = (New-Secret 40)
    }
    $changed = $false
    foreach ($key in $replacements.Keys) {
        if ($raw.Contains($key)) { $raw = $raw.Replace($key, $replacements[$key]); $changed = $true }
    }
    if ($changed) {
        [IO.File]::WriteAllText((Resolve-Path '.env'), $raw, (New-Object Text.UTF8Encoding($false)))
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
    Ensure-EnvFile
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

function Test-Url([string]$Url) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    } catch { return $false }
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return $false }
    & docker info *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-Postgres {
    if (-not (Test-Docker)) { return $false }
    & docker compose exec -T postgres pg_isready *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-Workflow {
    if (-not (Test-Url 'http://127.0.0.1:5678/healthz')) { return $false }
    $listed = (& docker compose exec -T n8n n8n list:workflow 2>&1 | Out-String)
    return ($LASTEXITCODE -eq 0 -and $listed -like '*Sistema Agêntico n8n WhatsApp+Email*')
}

function Test-N8nNeedsOwner {
    try {
        $settings = Invoke-RestMethod -Uri 'http://127.0.0.1:5678/rest/settings' -Method Get -TimeoutSec 3
        return [bool]$settings.data.userManagement.showSetupOnFirstLoad
    } catch { return $false }
}

function Get-StatusObject {
    $envMap = Get-EnvMap
    return [ordered]@{
        docker = (Test-Docker)
        postgres = (Test-Postgres)
        ollama = (Test-Url 'http://127.0.0.1:11434/api/tags')
        n8n = (Test-Url 'http://127.0.0.1:5678/healthz')
        waha = (Test-Url 'http://127.0.0.1:3000/health')
        workflow = (Test-Workflow)
        needsOwner = (Test-N8nNeedsOwner)
        setupComplete = (Test-Path '.setup-complete')
        googleConfigured = [bool]($envMap.ContainsKey('GOOGLE_CLIENT_ID') -and $envMap['GOOGLE_CLIENT_ID'] -and $envMap.ContainsKey('GOOGLE_CLIENT_SECRET') -and $envMap['GOOGLE_CLIENT_SECRET'])
        wahaUser = if ($envMap.ContainsKey('WAHA_DASHBOARD_USERNAME')) { $envMap['WAHA_DASHBOARD_USERNAME'] } else { 'admin' }
        wahaPassword = if ($envMap.ContainsKey('WAHA_DASHBOARD_PASSWORD')) { $envMap['WAHA_DASHBOARD_PASSWORD'] } else { '' }
    }
}

function Read-RequestBody($Request) {
    if (-not $Request.HasEntityBody) { return '' }
    $reader = New-Object IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Write-Response($Response, [int]$StatusCode, [string]$ContentType, [string]$Body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentEncoding = [Text.Encoding]::UTF8
    $Response.Headers['Cache-Control'] = 'no-store'
    $Response.Headers['X-Content-Type-Options'] = 'nosniff'
    $Response.Headers['Content-Security-Policy'] = "default-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'"
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Response.OutputStream.Close()
}

function Write-Json($Response, [int]$StatusCode, $Object) {
    Write-Response $Response $StatusCode 'application/json; charset=utf-8' ($Object | ConvertTo-Json -Depth 8 -Compress)
}

function Invoke-Bootstrap([string]$Mode) {
    $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File $Bootstrap -Mode $Mode -NoOpen -NonInteractive 2>&1 | Out-String)
    $code = $LASTEXITCODE
    return [ordered]@{ code = $code; log = $output }
}

function Validate-Model([string]$Value) {
    return ($Value -match '^[A-Za-z0-9._:/-]{1,80}$')
}

if (-not (Test-Path $UiFile)) {
    Write-Host '[ERRO] setup/index.html nao foi encontrado.' -ForegroundColor Red
    exit 1
}

Ensure-EnvFile

$prefix = "http://127.0.0.1:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Host "[ERRO] Nao foi possivel abrir o assistente em $prefix" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host 'Feche outro programa que esteja usando a porta ou execute o instalador novamente.'
    exit 1
}

Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' Assistente Visual - Sistema Agentico' -ForegroundColor White
Write-Host " $prefix" -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host 'Esta janela pode permanecer minimizada enquanto voce usa o navegador.'
Start-Process $prefix

$script:Running = $true
try {
    while ($script:Running -and $listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath.ToLowerInvariant()
        try {
            if ($request.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
                Write-Response $response 200 'text/html; charset=utf-8' (Get-Content $UiFile -Raw)
                continue
            }

            if ($request.HttpMethod -eq 'GET' -and $path -eq '/api/status') {
                Write-Json $response 200 (Get-StatusObject)
                continue
            }

            if ($request.HttpMethod -eq 'GET' -and $path -eq '/api/config') {
                Ensure-EnvFile
                $envMap = Get-EnvMap
                $obj = [ordered]@{
                    approvalEmail = if ($envMap.ContainsKey('APPROVAL_EMAIL')) { $envMap['APPROVAL_EMAIL'] } else { '' }
                    model = if ($envMap.ContainsKey('OLLAMA_MODEL')) { $envMap['OLLAMA_MODEL'] } else { 'qwen3:4b' }
                    validatorModel = if ($envMap.ContainsKey('OLLAMA_VALIDATOR_MODEL')) { $envMap['OLLAMA_VALIDATOR_MODEL'] } else { 'qwen3:4b' }
                    timezone = if ($envMap.ContainsKey('GENERIC_TIMEZONE')) { $envMap['GENERIC_TIMEZONE'] } else { 'America/Sao_Paulo' }
                    googleClientId = if ($envMap.ContainsKey('GOOGLE_CLIENT_ID')) { $envMap['GOOGLE_CLIENT_ID'] } else { '' }
                    googleClientSecret = if ($envMap.ContainsKey('GOOGLE_CLIENT_SECRET')) { $envMap['GOOGLE_CLIENT_SECRET'] } else { '' }
                    googleCallback = 'http://localhost:5678/rest/oauth2-credential/callback'
                    wahaUser = if ($envMap.ContainsKey('WAHA_DASHBOARD_USERNAME')) { $envMap['WAHA_DASHBOARD_USERNAME'] } else { 'admin' }
                    wahaPassword = if ($envMap.ContainsKey('WAHA_DASHBOARD_PASSWORD')) { $envMap['WAHA_DASHBOARD_PASSWORD'] } else { '' }
                }
                Write-Json $response 200 $obj
                continue
            }

            if ($request.HttpMethod -eq 'POST' -and $path -eq '/api/config') {
                $raw = Read-RequestBody $request
                $data = $raw | ConvertFrom-Json
                $email = [string]$data.approvalEmail
                $model = [string]$data.model
                $validator = [string]$data.validatorModel
                $timezone = [string]$data.timezone
                $googleClientId = if ($data.PSObject.Properties.Name -contains 'googleClientId') { [string]$data.googleClientId } else { '' }
                $googleClientSecret = if ($data.PSObject.Properties.Name -contains 'googleClientSecret') { [string]$data.googleClientSecret } else { '' }

                if ($email -and $email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Informe um e-mail de aprovacao valido ou deixe o campo vazio.' }
                if (-not (Validate-Model $model) -or -not (Validate-Model $validator)) { throw 'Nome de modelo Ollama invalido.' }
                if ($timezone -notmatch '^[A-Za-z_]+/[A-Za-z_]+$' -and $timezone -ne 'UTC') { throw 'Fuso horario invalido.' }
                if (($googleClientId -and -not $googleClientSecret) -or ($googleClientSecret -and -not $googleClientId)) { throw 'Para preparar Google automaticamente, informe Client ID e Client Secret juntos.' }
                if ($googleClientId -and $googleClientId.Length -gt 512) { throw 'Google Client ID invalido.' }
                if ($googleClientSecret -and $googleClientSecret.Length -gt 512) { throw 'Google Client Secret invalido.' }

                Ensure-EnvFile
                Set-EnvValue 'APPROVAL_EMAIL' $email
                Set-EnvValue 'OLLAMA_MODEL' $model
                Set-EnvValue 'OLLAMA_VALIDATOR_MODEL' $validator
                Set-EnvValue 'GENERIC_TIMEZONE' $timezone
                Set-EnvValue 'GOOGLE_CLIENT_ID' $googleClientId
                Set-EnvValue 'GOOGLE_CLIENT_SECRET' $googleClientSecret
                Write-Json $response 200 ([ordered]@{ ok = $true; googleConfigured = [bool]($googleClientId -and $googleClientSecret) })
                continue
            }

            if ($request.HttpMethod -eq 'POST' -and $path -eq '/api/install') {
                $result = Invoke-Bootstrap 'Prepare'
                if ($result.code -ne 0) {
                    Write-Json $response 500 ([ordered]@{ error = 'A preparacao automatica falhou. Veja os detalhes tecnicos.'; log = $result.log; code = $result.code })
                } else {
                    Write-Json $response 200 ([ordered]@{ ok = $true; log = $result.log; status = (Get-StatusObject) })
                }
                continue
            }

            if ($request.HttpMethod -eq 'POST' -and $path -eq '/api/finalize') {
                if (Test-N8nNeedsOwner) {
                    Write-Json $response 200 ([ordered]@{ ok = $false; needsOwner = $true })
                    continue
                }
                $result = Invoke-Bootstrap 'Finalize'
                if ($result.code -eq 20) {
                    Write-Json $response 200 ([ordered]@{ ok = $false; needsOwner = $true; log = $result.log })
                } elseif ($result.code -ne 0) {
                    Write-Json $response 500 ([ordered]@{ error = 'A finalizacao automatica falhou.'; log = $result.log; code = $result.code })
                } else {
                    Write-Json $response 200 ([ordered]@{ ok = $true; needsOwner = $false; log = $result.log; status = (Get-StatusObject) })
                }
                continue
            }

            if ($request.HttpMethod -eq 'POST' -and $path -eq '/api/start') {
                $result = Invoke-Bootstrap 'Start'
                if ($result.code -ne 0) { Write-Json $response 500 ([ordered]@{ error='Falha ao iniciar o sistema.'; log=$result.log }) }
                else { Write-Json $response 200 ([ordered]@{ ok=$true; log=$result.log; status=(Get-StatusObject) }) }
                continue
            }

            if ($request.HttpMethod -eq 'POST' -and $path -eq '/api/shutdown') {
                Write-Json $response 200 ([ordered]@{ ok = $true })
                $script:Running = $false
                continue
            }

            Write-Json $response 404 ([ordered]@{ error = 'Rota nao encontrada.' })
        } catch {
            if ($response.OutputStream.CanWrite) {
                Write-Json $response 500 ([ordered]@{ error = $_.Exception.Message })
            }
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}

exit 0
