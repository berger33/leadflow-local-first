@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Importar Sistema Agentico no n8n

echo ============================================================
echo  Importando n8n-agent-workflow.json
echo ============================================================

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Docker Desktop nao esta em execucao.
  pause
  exit /b 1
)

docker compose ps n8n | findstr /i "Up running" >nul 2>&1
if errorlevel 1 (
  echo [INFO] Iniciando stack antes da importacao...
  docker compose up -d
  timeout /t 10 /nobreak >nul
)

docker compose exec -T n8n n8n import:workflow --input=/files/n8n-agent-workflow.json
if errorlevel 1 (
  echo.
  echo [ERRO] A importacao automatica falhou.
  echo Alternativa: abra http://127.0.0.1:5678 e use Import from File.
  echo Arquivo: n8n-agent-workflow.json
  pause
  exit /b 1
)

echo.
echo [OK] Workflow importado com sucesso.
echo Abra http://127.0.0.1:5678, selecione as credenciais e teste pelo Chat de Teste.
pause
