@echo off
setlocal
cd /d "%~dp0"
title LeadFlow - Importar workflows n8n

echo Importando workflows do LeadFlow no n8n...
echo Certifique-se de ja ter aberto http://localhost:5678 e criado o usuario administrador.
echo.

docker compose exec -T n8n n8n import:workflow --input=/workflows/daily-technology-news.json
if errorlevel 1 goto :error

docker compose exec -T n8n n8n import:workflow --input=/workflows/research-on-demand.json
if errorlevel 1 goto :error

docker compose exec -T n8n n8n import:workflow --input=/workflows/daily-whatsapp-summary.json
if errorlevel 1 goto :error

echo.
echo [OK] Importacao concluida.
echo Abra http://localhost:5678, revise os workflows e conecte a credencial Gmail no workflow diario.
start "" "http://localhost:5678"
pause
exit /b 0

:error
echo.
echo [ERRO] O n8n nao aceitou a importacao por CLI nesta versao.
echo Use o metodo universal: Workflows ^> Import from File e selecione os JSON da pasta n8n\workflows.
pause
exit /b 1
