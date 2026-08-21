@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Sistema Agentico n8n WhatsApp+Email

echo ============================================================
echo  Sistema Agentico n8n WhatsApp+Email
echo  n8n + Ollama + WAHA + PostgreSQL + Human-in-the-loop
echo ============================================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Docker Desktop nao foi encontrado no PATH.
  echo Instale o Docker Desktop e execute este arquivo novamente.
  pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Docker Desktop esta instalado, mas o Engine nao esta ativo.
  echo Abra o Docker Desktop, aguarde ficar pronto e tente novamente.
  pause
  exit /b 1
)

if not exist ".env" (
  echo [1/6] Criando .env seguro a partir de .env.example...
  copy /Y ".env.example" ".env" >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='.env'; $c=Get-Content $p -Raw; $rnd1=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'); $rnd2=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'); $rnd3=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'); $rnd4=[guid]::NewGuid().ToString('N'); $c=$c.Replace('CHANGE_ME_STRONG_DATABASE_PASSWORD',$rnd1).Replace('CHANGE_ME_64_CHARS_OR_MORE',$rnd2).Replace('CHANGE_ME_32_CHARS_OR_MORE',$rnd3).Replace('CHANGE_ME_STRONG_PASSWORD',$rnd4); [IO.File]::WriteAllText((Resolve-Path $p),$c,(New-Object Text.UTF8Encoding($false)))"
  echo [OK] Segredos locais foram gerados automaticamente.
  echo [ATENCAO] Edite .env e ajuste APPROVAL_EMAIL antes de testar acoes destrutivas.
) else (
  echo [1/6] .env ja existe; mantendo configuracao atual.
)

echo [2/6] Validando Docker Compose...
docker compose config --quiet
if errorlevel 1 (
  echo [ERRO] docker-compose.yml ou .env possui configuracao invalida.
  pause
  exit /b 1
)

echo [3/6] Subindo PostgreSQL, Ollama, WAHA e n8n...
docker compose up -d
if errorlevel 1 (
  echo [ERRO] Falha ao iniciar containers.
  docker compose ps
  pause
  exit /b 1
)

echo [4/6] Aguardando n8n inicializar...
set /a tentativas=0
:waitn8n
set /a tentativas+=1
curl -s -o nul -w "%%{http_code}" http://127.0.0.1:5678/healthz | findstr /c:"200" >nul 2>&1
if not errorlevel 1 goto n8nready
if %tentativas% GEQ 60 goto n8ntimeout
timeout /t 3 /nobreak >nul
goto waitn8n

:n8nready
echo [OK] n8n respondeu ao health check.
echo [5/6] Importando workflow principal...
docker compose exec -T n8n n8n import:workflow --input=/files/n8n-agent-workflow.json >nul 2>&1
if errorlevel 1 (
  echo [AVISO] A importacao automatica nao concluiu. Use IMPORTAR_WORKFLOWS_WINDOWS.bat ou importe o JSON manualmente no n8n.
) else (
  echo [OK] Workflow importado.
)

echo [6/6] Abrindo paineis...
start "" "http://127.0.0.1:5678"
start "" "http://127.0.0.1:3000/dashboard"

echo.
echo ============================================================
echo  PRIMEIRA CONFIGURACAO
echo ============================================================
echo 1. No n8n, crie o usuario administrador local.
echo 2. Crie uma credencial Ollama apontando para http://ollama:11434.
echo 3. Conecte sua credencial Gmail OAuth2 aos nos Gmail.
echo 4. Conecte Google Calendar OAuth2 ao no criar_evento.
echo 5. No WAHA, inicie a sessao default e escaneie o QR Code.
echo 6. Abra o workflow e selecione as credenciais nos respectivos nos.
echo 7. Ative o workflow somente depois de testar pelo Chat de Teste.
echo.
echo Acoes apagar_email e enviar_whatsapp param no no Wait e exigem
 echo aprovacao humana pelo e-mail definido em APPROVAL_EMAIL.
echo ============================================================
pause
exit /b 0

:n8ntimeout
echo [AVISO] n8n demorou mais que o esperado para responder.
echo Consulte: docker compose logs --tail=120 n8n
pause
