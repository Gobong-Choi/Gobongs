@echo off
rem Handpilot installer launcher (double-click). Downloads setup.ps1 from the install page and runs it.
rem Keep this file ASCII-only: cmd.exe reads .cmd files in the OEM code page.
rem Source: handpilot repo web/handpilot-setup.cmd  (copy to Gobongs repo handpilot/handpilot-setup.cmd)
title Handpilot setup
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $f = Join-Path $env:TEMP 'handpilot-setup.ps1'; try { Invoke-WebRequest -UseBasicParsing 'https://gobong-choi.github.io/Gobongs/handpilot/setup.ps1' -OutFile $f } catch { Write-Host ('Download failed: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }; & $f; exit $LASTEXITCODE"
echo.
if not defined HANDPILOT_SETUP_TEST pause
