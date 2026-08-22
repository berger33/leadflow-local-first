@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Diagnostico - Sistema Agentico n8n WhatsApp+Email

echo ============================================================
echo  Diagnostico do Sistema Agentico
echo ============================================================

echo.
echo [Docker]
where docker >nul 2>&1
if errorlevel 1 (
  echo Docker CLI nao encontrado.
  goto :fim
)
docker info --format "Engine: {{.ServerVersion}}" 2>nul || echo Docker Engine indisponivel.

echo.
echo [Compose]
docker compose config --quiet && echo Compose: OK || echo Compose: ERRO

echo.
echo [Containers atuais]
docker compose ps -a

echo.
echo [Containers legados que podem causar conflito]
for %%C in (sistema-agentico-ollama-init sistema-agentico-ollama sistema-agentico-postgres sistema-agentico-n8n sistema-agentico-waha) do (
  docker ps -a --format "{{.Names}}" | findstr /x /c:"%%C" >nul 2>&1 && echo Encontrado: %%C
)

echo.
echo [PostgreSQL]
docker compose exec -T postgres pg_isready -U n8n -d n8n 2>nul || echo PostgreSQL ainda nao esta pronto.

echo.
echo [Ollama API]
curl -fsS http://127.0.0.1:11434/api/tags 2>nul && echo. || echo Ollama sem resposta na porta 11434.

echo.
echo [Modelos Ollama]
docker compose exec -T ollama ollama list 2>nul || echo Nao foi possivel listar os modelos.

echo.
echo [n8n]
curl -fsS http://127.0.0.1:5678/healthz 2>nul && echo. || echo n8n sem resposta na porta 5678.

echo.
echo [WAHA]
curl -fsS http://127.0.0.1:3000/health 2>nul && echo. || echo WAHA sem resposta na porta 3000.

echo.
echo [Ultimos logs PostgreSQL]
docker compose logs --tail=30 postgres

echo.
echo [Ultimos logs Ollama]
docker compose logs --tail=50 ollama

echo.
echo [Ultimos logs n8n]
docker compose logs --tail=60 n8n

echo.
echo [Ultimos logs WAHA]
docker compose logs --tail=40 waha

:fim
echo.
echo ============================================================
echo  O bootstrap nao depende mais do antigo ollama-init.
echo  Se um modelo falhar, INICIAR_WINDOWS.bat tenta o download 3 vezes
echo  e mostra o erro real sem derrubar os demais dados persistentes.
echo ============================================================
pause
