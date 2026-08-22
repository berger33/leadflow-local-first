@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Instalador Visual - Sistema Agentico

echo ============================================================
echo  Sistema Agentico n8n WhatsApp+Email
echo  Abrindo assistente visual de instalacao...
echo ============================================================
echo.

where powershell >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Windows PowerShell nao foi encontrado.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-wizard.ps1"
set "SETUP_EXIT=%ERRORLEVEL%"

if not "%SETUP_EXIT%"=="0" (
  echo.
  echo [ERRO] O assistente de instalacao foi encerrado com erro.
  echo Execute DIAGNOSTICO_WINDOWS.bat para obter mais detalhes.
  pause
  exit /b %SETUP_EXIT%
)

exit /b 0
