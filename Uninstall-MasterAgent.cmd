@echo off
rem Akzo Master SDD Agent - uninstall (asks first; keeps repos.json, tasks, inbox, specs, backups).
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\Install-MasterAgent.ps1" -Action Uninstall %*
