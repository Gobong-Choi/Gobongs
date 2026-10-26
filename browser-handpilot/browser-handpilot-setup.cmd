@echo off
rem Browser Hand-pilot installer launcher (double-click). Downloads setup.ps1 from the install page and runs it.
rem Keep this file ASCII-only: cmd.exe reads .cmd files in the OEM code page.
rem Source: Browser Hand-pilot project web/browser-handpilot-setup.cmd (copy to Gobongs repo browser-handpilot/)
title Browser Hand-pilot setup
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $f = Join-Path $env:TEMP 'browser-handpilot-setup.ps1'; try { Invoke-WebRequest -UseBasicParsing 'https://gobong-choi.github.io/Gobongs/browser-handpilot/setup.ps1' -OutFile $f } catch { Write-Host ('Download failed: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }; & $f; exit $LASTEXITCODE"
echo.
pause
