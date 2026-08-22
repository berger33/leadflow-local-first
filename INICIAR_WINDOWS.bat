@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Sistema Agentico n8n WhatsApp+Email

echo ============================================================
echo  Sistema Agentico n8n WhatsApp+Email
echo ============================================================
echo.

if not exist ".setup-complete" (
  echo [INFO] Primeira execucao detectada.
  echo [INFO] Abrindo assistente visual de instalacao...
  call "%~dp0INSTALAR_WINDOWS.bat"
  exit /b %ERRORLEVEL%
)

where powershell >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Windows PowerShell nao foi encontrado.
  pause
  exit /b 1
)

echo [INFO] Configuracao existente encontrada. Iniciando servicos...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1" -Mode Start
set "BOOTSTRAP_EXIT=%ERRORLEVEL%"

if not "%BOOTSTRAP_EXIT%"=="0" (
  echo.
  echo [ERRO] Nao foi possivel iniciar o sistema.
  echo Execute DIAGNOSTICO_WINDOWS.bat para detalhes.
  pause
  exit /b %BOOTSTRAP_EXIT%
)

echo.
echo [OK] Sistema disponivel.
pause
exit /b 0
