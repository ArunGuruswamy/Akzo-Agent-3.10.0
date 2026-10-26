@echo off
rem Akzo Master SDD Agent - install, upgrade, repair, verify, or uninstall (window).
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\Install-MasterAgent.ps1" %*
