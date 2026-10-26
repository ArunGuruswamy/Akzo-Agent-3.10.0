<#
.SYNOPSIS
  One-click front end for install.ps1: install/upgrade, repair, verify, uninstall, and repository registration.
.DESCRIPTION
  Started by Install-MasterAgent.cmd / Uninstall-MasterAgent.cmd. Shows a small window (Windows Forms) unless
  -NoGui is given. Every action runs scripts\install.ps1 in a child Windows PowerShell, so its backups, manifest,
  rollback, and target-repository checks apply unchanged.
    Install  = install or upgrade (idempotent; also registers repositories chosen with "Add repository")
    Repair   = install + restore missing/modified files + remove Akzo text from VS Code Copilot memory (backed up)
    Verify   = install.ps1 -Verify
    Uninstall= install.ps1 -Uninstall (asks first in the window)
.EXAMPLE
  .\scripts\Install-MasterAgent.ps1                                   # window
  .\scripts\Install-MasterAgent.ps1 -Action Install -Repo C:\src\backend -NoGui
  .\scripts\Install-MasterAgent.ps1 -Action Uninstall                 # confirmation window, then uninstall
.NOTES
  Akzo SDD Agent — Developed and maintained by Arun RG
#>
[CmdletBinding()]
param(
    [ValidateSet('', 'Install', 'Repair', 'Verify', 'Uninstall')]
    [string]$Action = '',
    [string[]]$Repo,
    [switch]$NoGui,
    [switch]$NoVSCodeSettings,
    [string]$HomeRoot = $env:USERPROFILE
)
$ErrorActionPreference = 'Stop'
$Engine = Join-Path $PSScriptRoot 'install.ps1'
$Source = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content (Join-Path $Source 'VERSION') -TotalCount 1).Trim()

function Invoke-Engine([string]$what, [string[]]$repos) {
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Engine, '-HomeRoot', $HomeRoot)
    switch ($what) {
        'Install' { if (-not $NoVSCodeSettings) { $a += '-ConfigureVSCode' } }
        'Repair' { $a += '-CleanMemory'; if (-not $NoVSCodeSettings) { $a += '-ConfigureVSCode' } }
        'Verify' { $a += '-Verify' }
        'Uninstall' { $a += '-Uninstall' }
    }
    if ($what -in 'Install', 'Repair' -and @($repos | Where-Object { $_ }).Count) { $a += '-AddRepo'; $a += ($repos -join ';') }
    $ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1: redirected native stderr must not abort
    $out = & powershell.exe @a 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ code = $LASTEXITCODE; text = ($out -join [Environment]::NewLine) }
}

function Get-RegisteredRepo {
    $reg = Join-Path $HomeRoot '.akzo-agent\repos.json'
    if (-not (Test-Path $reg)) { return @() }
    try { @((Get-Content $reg -Raw -Encoding UTF8 | ConvertFrom-Json).repos | Where-Object { $_.path } | ForEach-Object { "$($_.id)  ->  $($_.path)" }) } catch { @("repos.json is not valid JSON: $reg") }
}

function Get-InstalledVersion {
    $m = Join-Path $HomeRoot '.akzo-agent\install-manifest.json'
    if (Test-Path $m) { try { (Get-Content $m -Raw | ConvertFrom-Json).version } catch { 'unknown' } } else { 'not installed' }
}

if ($NoGui) {
    if (-not $Action) { throw '-NoGui needs -Action Install, Repair, Verify, or Uninstall.' }
    $r = Invoke-Engine $Action $Repo
    Write-Output $r.text
    exit $r.code
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

if ($Action -eq 'Uninstall') {   # Uninstall-MasterAgent.cmd: confirm, run, show the result
    $ok = [Windows.Forms.MessageBox]::Show("Remove the Akzo Master SDD agent (installed version $(Get-InstalledVersion))?`n`nKept: your repos.json, tasks, inbox, specs, and backups in $HomeRoot\.akzo-agent.", 'Uninstall Akzo Master SDD Agent', 'YesNo', 'Question')
    if ($ok -ne 'Yes') { exit 0 }
    $r = Invoke-Engine 'Uninstall' @()
    [void][Windows.Forms.MessageBox]::Show(($r.text -split "`r?`n" | Select-Object -Last 15) -join "`n", $(if ($r.code -eq 0) { 'Uninstalled' } else { 'Uninstall reported a problem' }), 'OK', $(if ($r.code -eq 0) { 'Information' } else { 'Warning' }))
    exit $r.code
}

$pending = New-Object Collections.ArrayList   # repositories chosen in this window, registered by the next Install/Repair
$form = New-Object Windows.Forms.Form -Property @{ Text = "Akzo Master SDD Agent $Version - Setup"; Width = 760; Height = 560; StartPosition = 'CenterScreen'; FormBorderStyle = 'FixedDialog'; MaximizeBox = $false }
$info = New-Object Windows.Forms.Label -Property @{ Left = 12; Top = 10; Width = 720; Height = 36; Font = New-Object Drawing.Font('Segoe UI', 9) }
$repoLabel = New-Object Windows.Forms.Label -Property @{ Left = 12; Top = 50; Width = 300; Text = 'Repositories the agent works in:' }
$repoList = New-Object Windows.Forms.ListBox -Property @{ Left = 12; Top = 72; Width = 590; Height = 70 }
$addRepo = New-Object Windows.Forms.Button -Property @{ Left = 612; Top = 72; Width = 120; Height = 30; Text = 'Add repository...' }
$vscode = New-Object Windows.Forms.CheckBox -Property @{ Left = 12; Top = 148; Width = 600; Checked = -not $NoVSCodeSettings; Text = 'Configure VS Code for fewer prompts (helper auto-approve, read access, 400 agent steps)' }
$buttons = foreach ($b in 'Install / Upgrade', 'Repair', 'Verify', 'Uninstall', 'Close') { New-Object Windows.Forms.Button -Property @{ Text = $b; Width = 130; Height = 32; Top = 178 } }
for ($i = 0; $i -lt $buttons.Count; $i++) { $buttons[$i].Left = 12 + $i * 144 }
$log = New-Object Windows.Forms.TextBox -Property @{ Left = 12; Top = 220; Width = 720; Height = 290; Multiline = $true; ScrollBars = 'Vertical'; ReadOnly = $true; Font = New-Object Drawing.Font('Consolas', 8.5) }
$form.Controls.AddRange(@($info, $repoLabel, $repoList, $addRepo, $vscode) + $buttons + @($log))

function Show-Status {
    $info.Text = "This folder: v$Version.  Installed: $(Get-InstalledVersion).`nAfter installing: open VS Code or Visual Studio 2026, select 'akzo-master-sdd' in Copilot Chat, and type 'Start Development'."
    $repoList.Items.Clear()
    foreach ($r in @(Get-RegisteredRepo) + @($pending | ForEach-Object { "(will be added)  $_" })) { [void]$repoList.Items.Add($r) }
    if (-not $repoList.Items.Count) { [void]$repoList.Items.Add('(none yet - use "Add repository..." to choose your local Git clone)') }
}

function Invoke-SetupAction([string]$what) {
    $script:NoVSCodeSettings = -not $vscode.Checked
    $form.Cursor = 'WaitCursor'; $log.Text = "Running $what ..."; $form.Refresh()
    try { $r = Invoke-Engine $what @($pending) } finally { $form.Cursor = 'Default' }
    $log.Text = $r.text + [Environment]::NewLine + $(if ($r.code -eq 0) { "== $what finished OK ==" } else { "== $what reported problems (exit $($r.code)) ==" })
    $log.SelectionStart = $log.Text.Length; $log.ScrollToCaret()
    if ($r.code -eq 0 -and $what -in 'Install', 'Repair') { $pending.Clear() }
    Show-Status
    $r.code
}

$addRepo.Add_Click({
        $dlg = New-Object Windows.Forms.FolderBrowserDialog -Property @{ Description = 'Select the local Git repository (clone) the agent should develop in'; ShowNewFolderButton = $false }
        if ($dlg.ShowDialog($form) -eq 'OK') {
            if (Test-Path (Join-Path $dlg.SelectedPath '.git')) { [void]$pending.Add($dlg.SelectedPath); Show-Status; $log.Text = "Selected $($dlg.SelectedPath). Click 'Install / Upgrade' to register it." }
            else { [void][Windows.Forms.MessageBox]::Show("$($dlg.SelectedPath) is not the root of a Git repository (no .git folder).", 'Add repository', 'OK', 'Warning') }
        }
    })
$buttons[0].Add_Click({
        $code = Invoke-SetupAction 'Install'
        if ($code -eq 0 -and -not @(Get-RegisteredRepo).Count) { $log.AppendText([Environment]::NewLine + 'No repository registered yet: click "Add repository..." and then "Install / Upgrade" again.') }
    })
$buttons[1].Add_Click({ [void](Invoke-SetupAction 'Repair') })
$buttons[2].Add_Click({ [void](Invoke-SetupAction 'Verify') })
$buttons[3].Add_Click({
        if ([Windows.Forms.MessageBox]::Show('Remove the agent? Your repos.json, tasks, inbox, specs, and backups are kept.', 'Uninstall', 'YesNo', 'Question') -eq 'Yes') { [void](Invoke-SetupAction 'Uninstall') }
    })
$buttons[4].Add_Click({ $form.Close() })
Show-Status
if ($Action) { $form.Add_Shown({ [void](Invoke-SetupAction $Action) }) }
[void]$form.ShowDialog()
