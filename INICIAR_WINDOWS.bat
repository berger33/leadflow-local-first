@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title LeadFlow Local-First - Inicializacao

echo ============================================================
echo  LeadFlow Local-First - Assistente IA + WhatsApp + n8n
echo ============================================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Docker Desktop nao foi encontrado no PATH.
  echo Instale o Docker Desktop, reinicie o Windows se necessario e tente novamente.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Docker Desktop esta instalado, mas nao esta em execucao.
  echo Abra o Docker Desktop e aguarde o status Engine running.
  pause
  exit /b 1
)

if not exist ".env" (
  echo [1/5] Criando .env a partir do modelo...
  copy /Y ".env.example" ".env" >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='.env'; $c=Get-Content $p -Raw; $c=$c.Replace('CHANGE_ME_32_CHARS_OR_MORE',([guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'))); $c=$c.Replace('CHANGE_ME_STRONG_PASSWORD',([guid]::NewGuid().ToString('N'))); $c=$c.Replace('CHANGE_ME_ANOTHER_LONG_RANDOM_SECRET',([guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'))); [System.IO.File]::WriteAllText((Join-Path (Get-Location) $p),$c,(New-Object System.Text.UTF8Encoding($false)))"
  if errorlevel 1 (
    echo [ERRO] Nao foi possivel gerar os segredos no .env.
    pause
    exit /b 1
  )
  echo [OK] Segredos locais fortes foram gerados automaticamente.
  echo IMPORTANTE: edite .env e troque GMAIL_REPORT_TO pelo seu Gmail antes de ativar o workflow de e-mail.
) else (
  echo [1/5] Arquivo .env encontrado.
)

echo [2/5] Validando configuracao do Docker Compose...
docker compose config --quiet
if errorlevel 1 (
  echo [ERRO] O arquivo .env ou docker-compose.yml possui configuracao invalida.
  echo Revise o .env e execute novamente.
  pause
  exit /b 1
)

echo [3/5] Construindo e iniciando os containers...
docker compose up -d --build
if errorlevel 1 (
  echo [ERRO] Falha ao iniciar os containers.
  echo Rode: docker compose logs --tail=100
  pause
  exit /b 1
)

echo [4/5] Aguardando servicos principais...
timeout /t 8 /nobreak >nul

echo [5/5] Status dos containers:
docker compose ps

echo.
echo Abrindo paineis locais...
start "" "http://localhost:3000/dashboard"
start "" "http://localhost:5678"
start "" "http://localhost:8000/docs"

echo.
echo ============================================================
echo  PROXIMOS PASSOS - somente na primeira execucao
echo ============================================================
echo 1. WAHA: http://localhost:3000/dashboard
echo    - use usuario/senha e WAHA_API_KEY do .env
echo    - crie/inicie a sessao default e escaneie o QR Code
echo.
echo 2. n8n: http://localhost:5678
echo    - crie o usuario administrador local
echo    - execute IMPORTAR_WORKFLOWS_WINDOWS.bat
echo    - conecte a credencial Gmail no workflow diario e ative-o
echo.
echo 3. API: http://localhost:8000/docs
echo.
echo Depois disso, envie uma mensagem para o WhatsApp conectado.
echo ============================================================
pause
