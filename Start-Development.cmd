@echo off
rem Akzo Master SDD Agent - choose the refined PBI file and queue it for the agent.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\Start-Development.ps1" %*
