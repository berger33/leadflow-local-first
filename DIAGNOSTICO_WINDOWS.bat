@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Diagnostico - Sistema Agentico n8n WhatsApp+Email

echo ============================================================
echo  Diagnostico do Sistema Agentico
echo ============================================================

echo.
echo [Docker]
where docker || echo Docker CLI nao encontrado.
docker info --format "Engine: {{.ServerVersion}}" 2>nul || echo Docker Engine indisponivel.

echo.
echo [Compose]
docker compose config --quiet && echo Compose: OK || echo Compose: ERRO

echo.
echo [Containers]
docker compose ps

echo.
echo [n8n]
curl -s http://127.0.0.1:5678/healthz && echo. || echo n8n sem resposta.

echo.
echo [WAHA]
curl -s http://127.0.0.1:3000/health && echo. || echo WAHA sem resposta.

echo.
echo [Ollama]
curl -s http://127.0.0.1:11434/api/tags && echo. || echo Ollama sem resposta.

echo.
echo [Ultimos logs n8n]
docker compose logs --tail=30 n8n

echo.
echo [Ultimos logs WAHA]
docker compose logs --tail=20 waha

echo.
echo [Ultimos logs Ollama]
docker compose logs --tail=20 ollama

echo.
echo [Ultimos logs PostgreSQL]
docker compose logs --tail=20 postgres

echo.
echo ============================================================
echo  Verifique tambem as credenciais Ollama, Gmail e Calendar no n8n.
echo ============================================================
pause
