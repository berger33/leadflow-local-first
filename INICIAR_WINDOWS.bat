@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Sistema Agentico n8n WhatsApp+Email

echo ============================================================
echo  Sistema Agentico n8n WhatsApp+Email
echo  Inicializacao inteligente e autorreparavel
echo ============================================================
echo.

where powershell >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Windows PowerShell nao foi encontrado.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1"
set "BOOTSTRAP_EXIT=%ERRORLEVEL%"

echo.
if not "%BOOTSTRAP_EXIT%"=="0" (
  echo [ERRO] A inicializacao nao foi concluida.
  echo Execute DIAGNOSTICO_WINDOWS.bat para obter os detalhes.
  pause
  exit /b %BOOTSTRAP_EXIT%
)

echo [OK] Sistema inicializado.
pause
exit /b 0
