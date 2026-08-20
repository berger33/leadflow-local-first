@echo off
setlocal
cd /d "%~dp0"
title LeadFlow - Diagnostico

echo === Docker ===
docker --version
docker compose version
echo.
echo === Containers ===
docker compose ps
echo.
echo === API LeadFlow ===
powershell -NoProfile -Command "try { Invoke-RestMethod http://localhost:8000/health | ConvertTo-Json -Depth 6 } catch { Write-Host $_.Exception.Message -ForegroundColor Red }"
echo.
echo === Ollama ===
powershell -NoProfile -Command "try { Invoke-RestMethod http://localhost:11434/api/tags | ConvertTo-Json -Depth 5 } catch { Write-Host $_.Exception.Message -ForegroundColor Red }"
echo.
echo === WAHA ===
powershell -NoProfile -Command "try { Invoke-RestMethod http://localhost:3000/health | ConvertTo-Json -Depth 5 } catch { Write-Host $_.Exception.Message -ForegroundColor Red }"
echo.
echo === n8n ===
powershell -NoProfile -Command "try { (Invoke-WebRequest http://localhost:5678 -UseBasicParsing).StatusCode } catch { Write-Host $_.Exception.Message -ForegroundColor Red }"
echo.
echo === Ultimos logs ===
docker compose logs --tail=25 assistant
pause
