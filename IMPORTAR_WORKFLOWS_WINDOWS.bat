@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Importar Sistema Agentico no n8n

echo ============================================================
echo  Sistema Agentico - Importacao segura do workflow
echo ============================================================
echo.
echo O bootstrap agora inicia/repara os servicos, valida o modelo,
echo aguarda o n8n e evita importar o mesmo workflow duas vezes.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1" -NoOpen
set "BOOTSTRAP_EXIT=%ERRORLEVEL%"

if not "%BOOTSTRAP_EXIT%"=="0" (
  echo.
  echo [ERRO] Nao foi possivel concluir a importacao.
  echo Execute DIAGNOSTICO_WINDOWS.bat para mais detalhes.
  pause
  exit /b %BOOTSTRAP_EXIT%
)

echo.
echo [OK] Stack verificado e workflow disponivel no n8n.
echo Abra http://127.0.0.1:5678
pause
exit /b 0
