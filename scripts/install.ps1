<#
.SYNOPSIS
  Installs, upgrades, repairs, verifies, or uninstalls the Akzo Master SDD GitHub Copilot agent at user level.
  Install-MasterAgent.cmd is the one-click front end for this script.

.DESCRIPTION
  Copies (no downloads, no admin rights) from this repository:
    copilot\agents\akzo-master-sdd.agent.md -> <HomeRoot>\.copilot\agents\    (VS Code)
                                            -> <HomeRoot>\.github\agents\     (Visual Studio 2026 default user location)
    copilot\modules\                        -> <HomeRoot>\.akzo-agent\modules\ (helper script and spec/plan templates)
  With -ConfigureVSCode it also adds a marked block to VS Code user settings (backed up first; removed by -Uninstall).
  It creates <HomeRoot>\.akzo-agent\repos.json from config\repos.example.json if missing, plus the tasks folder
  (repos.json 'tasksDir', default <HomeRoot>\.akzo-agent\tasks) and the inbox. repos.json is validated and only
  changed by -AddRepo (backed up first).
  Upgrade: files from earlier versions that are no longer shipped are backed up and removed (manifest), and
  earlier Akzo agent files found in agent folders without a manifest entry (e.g. akzo-sdd) are backed up and removed.
  If a write fails, every file changed by this run is restored from its backup (rollback).
  Isolation: the agent file is the only file placed where Copilot discovers customizations. Workflow modules
  are deliberately NOT installed as skills, because both IDEs offer discovered skills to every agent.
  -Verify also reports Akzo text in places Copilot loads for every agent (shared instruction/prompt folders,
  VS Code Copilot memory); -CleanMemory backs up and removes such VS Code memory files.
  Every written file is recorded with its SHA-256 in <HomeRoot>\.akzo-agent\install-manifest.json.
  Any existing file that would be replaced or removed is first copied to <HomeRoot>\.akzo-agent\backups\<timestamp>\.
  Target repositories are never written; their HEAD and git status are compared before and after.
  Re-running is safe (repair): unchanged files are skipped, missing or modified files are restored.

.EXAMPLE
  .\scripts\install.ps1 -DryRun                    # preview
  .\scripts\install.ps1                            # install, upgrade, or repair
  .\scripts\install.ps1 -AddRepo C:\src\backend    # also register a repository in repos.json
  .\scripts\install.ps1 -Verify                    # check installed files, isolation, and leaks
  .\scripts\install.ps1 -CleanMemory               # repair and remove Akzo text from VS Code Copilot memory (backed up)
  .\scripts\install.ps1 -Uninstall                 # remove installed agent/modules (keeps registry and task artifacts)
.NOTES
  Akzo SDD Agent — Developed and maintained by Arun RG
#>
[CmdletBinding()]
param(
    [switch]$Verify,
    [switch]$Uninstall,
    [switch]$DryRun,
    [ValidateSet('All', 'VSCode', 'VisualStudio')]
    [string]$Target = 'All',
    [string]$HomeRoot = $env:USERPROFILE,
    # Visual Studio lets users change this in Tools > Options > GitHub > Copilot.
    [string]$VisualStudioAgentsDir,
    # Adds a marked block to VS Code user settings: auto-approve for the exact helper command line, and
    # read access to the Akzo folders. Backed up first; refreshed on reruns; removed by -Uninstall.
    [switch]$ConfigureVSCode,
    # Registers these local Git repositories in repos.json (idempotent; repos.json is backed up first).
    [string[]]$AddRepo,
    # Backs up and removes VS Code Copilot memory files that mention Akzo (they are loaded for every agent).
    [switch]$CleanMemory
)
$ErrorActionPreference = 'Stop'

$Source = Split-Path -Parent $PSScriptRoot
if (-not $HomeRoot -or -not (Test-Path $HomeRoot -PathType Container)) { throw "HomeRoot '$HomeRoot' does not exist." }
$HomeRoot = (Resolve-Path $HomeRoot).Path
$AkzoHome = Join-Path $HomeRoot '.akzo-agent'
$ManifestPath = Join-Path $AkzoHome 'install-manifest.json'
# A plain rerun (update, verify) keeps the choices recorded by the previous install.
$saved = if (Test-Path $ManifestPath) { Get-Content $ManifestPath -Raw | ConvertFrom-Json } else { $null }
if (-not $PSBoundParameters.ContainsKey('Target') -and $saved.target) { $Target = $saved.target }
if (-not $VisualStudioAgentsDir) {
    $VisualStudioAgentsDir = if ($saved.visualStudioAgentsDir) { $saved.visualStudioAgentsDir } else { Join-Path $HomeRoot '.github\agents' }
}
$ModulesDir = Join-Path $AkzoHome 'modules'
$SourceVersion = if (Test-Path (Join-Path $Source 'VERSION')) { (Get-Content (Join-Path $Source 'VERSION') -TotalCount 1).Trim() } else { 'unknown' }

# Package integrity: a release package (scripts\make-release.ps1) carries release-manifest.json with the SHA-256 of every
# file. A file that differs, is missing, or is not listed stops the install before anything is written. A working
# copy without a manifest installs as before (reported). Hashes show the package is unchanged since it was built; they
# do not show who built or approved it (organizational code signing does that, where required).
$ReleaseManifest = Join-Path $Source 'release-manifest.json'
if (Test-Path $ReleaseManifest) {
    $rm = Get-Content $ReleaseManifest -Raw | ConvertFrom-Json
    $listed = @{}; foreach ($f in @($rm.files)) { $listed[($f.path -replace '/', '\')] = $f.sha256 }
    $bad = @()
    foreach ($k in $listed.Keys) { $p = Join-Path $Source $k; if (-not (Test-Path -LiteralPath $p)) { $bad += "missing $k" } elseif ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $listed[$k]) { $bad += "modified $k" } }
    foreach ($f in Get-ChildItem $Source -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -ne $ReleaseManifest }) {
        $rel = $f.FullName.Substring($Source.Length + 1); if (-not $listed.ContainsKey($rel)) { $bad += "not in the release manifest $rel" }
    }
    if ($bad) { throw "PACKAGE INTEGRITY FAILED ($ReleaseManifest, version $($rm.version)): $($bad -join '; '). Do not install this package; get it again from the trusted source." }
    Write-Output "package integrity OK: $(@($rm.files).Count) file(s) match release-manifest.json (version $($rm.version))"
} else { Write-Output 'package integrity: no release-manifest.json (working copy, not a release package)' }
# Folders Copilot scans for skills/instructions for every agent (VS Code source + docs, Visual Studio docs).
$SharedSkillDirs = '.copilot\skills', '.agents\skills', '.claude\skills' | ForEach-Object { Join-Path $HomeRoot $_ }
$VSCodeUserDirs = 'Code', 'Code - Insiders' | ForEach-Object { Join-Path $HomeRoot "AppData\Roaming\$_\User" }
# The VS Code profile 'prompts' folder holds user-level instructions, prompts, and agents (applied to every chat).
$SharedInstructionDirs = @('.copilot\instructions', '.claude\rules' | ForEach-Object { Join-Path $HomeRoot $_ }) + @($VSCodeUserDirs | ForEach-Object { Join-Path $_ 'prompts' })
# Folders where an agent file is discovered; earlier Akzo agents left here (without a manifest entry) are migrated away.
$LegacyAgentNames = @('akzo-sdd.agent.md')
$VSCodeOnlyField = 'disable-model-invocation: true'   # VS Code: other agents cannot invoke the Akzo agents as subagents
$Registry = Join-Path $AkzoHome 'repos.json'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Sha = [System.Security.Cryptography.SHA256]::Create()

function Get-Hash([byte[]]$bytes) { ([BitConverter]::ToString($Sha.ComputeHash($bytes)) -replace '-', '') }
function Get-FileSha([string]$path) { Get-Hash ([IO.File]::ReadAllBytes($path)) }
function Say([string]$msg) { Write-Output $(if ($DryRun) { "[dry-run] $msg" } else { $msg }) }

$BackupOf = @{}   # original path -> backup copy made in this run (used for rollback)
function Backup([string]$path) {
    $root = Join-Path $AkzoHome "backups\$Stamp"
    $rel = $path -replace ':', ''   # full path keeps backups of files on other drives distinct
    $dest = Join-Path $root $rel
    if ($dest.Length -gt 240) {   # Windows PowerShell 5.1 cannot write past MAX_PATH (260): short name, listed in index.txt
        $dest = Join-Path $root ("long\" + (Get-Hash ([Text.Encoding]::UTF8.GetBytes($path))).Substring(0, 12) + '-' + (Split-Path $path -Leaf))
    }
    Say "backup  $path -> $dest"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $path $dest -Force
        Add-Content -LiteralPath (Join-Path $root 'index.txt') -Value "$path`t$dest" -Encoding UTF8
        $BackupOf[$path] = $dest
    }
}

# VS Code Copilot memory: user memory (loaded into every agent's context) and per-workspace repository memory.
function Get-AkzoMemoryFile {
    foreach ($u in $VSCodeUserDirs) {
        $dirs = @(Join-Path $u 'globalStorage\github.copilot-chat\memory-tool\memories') +
            @(Get-ChildItem (Join-Path $u 'workspaceStorage') -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'github.copilot-chat\memory-tool\memories\repo' })
        foreach ($d in $dirs | Where-Object { Test-Path -LiteralPath $_ }) {
            Get-ChildItem -LiteralPath $d -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern 'akzo' -List | ForEach-Object { $_.Path }
        }
    }
}

# Earlier Akzo agent files in discovery folders that this installer no longer ships (ownership: they name an Akzo agent).
function Get-LegacyAgentFile {
    $dirs = @((Join-Path $HomeRoot '.copilot\agents'), (Join-Path $HomeRoot '.github\agents'), $VisualStudioAgentsDir) + @($VSCodeUserDirs | ForEach-Object { Join-Path $_ 'prompts' })
    foreach ($d in $dirs | Sort-Object -Unique | Where-Object { Test-Path -LiteralPath $_ }) {
        foreach ($n in $LegacyAgentNames) {
            $f = Join-Path $d $n
            if ((Test-Path -LiteralPath $f) -and (Select-String -LiteralPath $f -Pattern 'Akzo (Master )?SDD Agent' -Quiet)) { $f }
        }
    }
}

# Adds a local Git repository to repos.json. specsDir follows a spec folder the repository already has.
function Add-Repository([string]$repoPath) {
    $top = if (Test-Path -LiteralPath $repoPath -PathType Container) { try { (& git -C $repoPath rev-parse --show-toplevel 2>$null) } catch { '' } }
    if (-not $top) { Write-Output "skip    AddRepo '$repoPath': not a Git repository; not registered."; return }
    $full = (Resolve-Path -LiteralPath $top).Path
    $cfg = Read-Config
    if (-not $cfg) { $cfg = Get-Content (Join-Path $Source 'config\repos.example.json') -Raw | ConvertFrom-Json }   # dry run before the registry exists
    $repos = @($cfg.repos | Where-Object { $_ })
    $same = $repos | Where-Object { (Test-GitRepo $_.path) -and (Resolve-Path -LiteralPath $_.path).Path -eq $full } | Select-Object -First 1
    if ($same) {
        Say "keep    repository '$($same.id)' -> $full (already registered)"
        if (-not $DryRun -and -not (Test-Path (Join-Path $AkzoHome "maps\$($same.id)\architecture.json"))) { Invoke-Discovery $same.id }   # e.g. after its authorization
        return
    }
    $base = ((Split-Path $full -Leaf) -replace '[^A-Za-z0-9._-]', '-').Trim('-', '.')
    if (-not $base) { $base = 'repo' }
    $id = $base
    for ($n = 2; $repos.id -contains $id; $n++) { $id = "$base-$n" }
    $specsDir = @('openspec/changes', 'src/.github/specs', '.github/specs', 'docs/specs', 'specs') | Where-Object { Test-Path -LiteralPath (Join-Path $full $_) } | Select-Object -First 1
    $stack = @()
    if (Get-ChildItem -LiteralPath $full -Filter *.sln -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1) { $stack += 'dotnet' }
    if (Get-ChildItem -LiteralPath $full -Filter angular.json -Recurse -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\node_modules\\' } | Select-Object -First 1) { $stack += 'angular' }
    $entry = [pscustomobject]@{ id = $id; path = $full; specsDir = "$specsDir"; purpose = ''; stack = $stack; notes = @(); commands = [pscustomobject]@{ build = ''; test = ''; codegen = ''; lint = '' }; verified = [pscustomobject]@{ date = ''; commit = '' } }
    # Unconfigured example entries (no path, never verified) would only show up as choices that cannot work.
    $kept = @($repos | Where-Object { $_.path -or $_.verified.date })
    $cfg.repos = @($kept) + $entry
    Backup $Registry
    Say "add     repository '$id' -> $full$(if ($specsDir) { " (specsDir $specsDir)" })"
    if (-not $DryRun) {
        [IO.File]::WriteAllText($Registry, ($cfg | ConvertTo-Json -Depth 6), $Utf8)
        Invoke-Discovery $id
    }
}

# First architecture discovery of a newly registered repository (the helper refreshes it later only when HEAD moves).
function Invoke-Discovery([string]$id) {
    $helper = Join-Path $ModulesDir 'investigate\scripts\akzo.ps1'
    if (-not (Test-Path $helper)) { return }
    $saved = $env:AKZO_AGENT_HOME
    $ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1: native stderr must not abort the installer
    try {
        $env:AKZO_AGENT_HOME = $AkzoHome
        # Discovery is repository processing: it waits for the G8 authorization (policy or the developer's statement).
        $pre = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper policy -Repo $id 2>$null) -join "`n" | ConvertFrom-Json
        if ($pre.preflight -ne 'OK') { Write-Output "skip    architecture discovery for '$id': $($pre.preflight) - $($pre.reason) (the agent asks for the authorization on first use)"; return }
        $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper discover -Repo $id 2>$null
        $d = ($raw -join "`n") | ConvertFrom-Json
        Say "discover architecture of '$id': $($d.files) files, stack: $(if ($d.stack) { $d.stack } else { 'not detected' }) -> $($d.architecture)"
    } catch { Write-Output "skip    architecture discovery for '$id' (the agent builds it on first use): $($_.Exception.Message)" }
    finally { $env:AKZO_AGENT_HOME = $saved }
}

function Test-GitRepo([string]$p) {   # tolerate empty or malformed paths from the user-edited registry
    try { [bool]($p -and (Test-Path -LiteralPath (Join-Path $p '.git'))) } catch { $false }
}

function Read-Config { if (Test-Path $Registry) { Get-Content $Registry -Raw -Encoding UTF8 | ConvertFrom-Json } }

# Same rule as the helper (akzo.ps1): repos.json 'tasksDir', default <AkzoHome>\tasks.
function Get-TasksDir($cfg) {
    $d = if ($cfg.tasksDir) { [Environment]::ExpandEnvironmentVariables($cfg.tasksDir) } else { Join-Path $AkzoHome 'tasks' }
    $d.TrimEnd('\', '/')
}

# Problems in the user-edited registry. Reported only; the registry is never rewritten.
function Test-Config {
    try { $cfg = Read-Config } catch { "repos.json is not valid JSON ($Registry): $($_.Exception.Message)"; return }
    $ids = @($cfg.repos | Where-Object { $_ } | ForEach-Object { "$($_.id)" })
    foreach ($g in $ids | Group-Object | Where-Object { $_.Count -gt 1 }) { "duplicate repo id '$($g.Name)' in $Registry" }
    foreach ($i in $ids | Where-Object { $_ -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' }) { "repo id '$i' must be a folder name (letters, digits, '.', '_', '-')" }
    $tasks = Get-TasksDir $cfg
    if (-not [IO.Path]::IsPathRooted($tasks)) { "tasksDir '$tasks' must be an absolute path"; return }
    $p = $tasks
    while ($p -and -not (Test-Path -LiteralPath $p)) { $p = Split-Path $p }
    $top = if ($p) { try { & git -C $p rev-parse --show-toplevel 2>$null } catch { '' } }
    if ($top) { "tasksDir '$tasks' is inside the Git repository '$top'; task files would show in Git Changes" }
}

$VSCodeSettings = Join-Path $HomeRoot 'AppData\Roaming\Code\User\settings.json'
$BlockStart = '// >>> akzo-sdd (added by install.ps1 -ConfigureVSCode; removed by -Uninstall)'
$BlockEnd = '// <<< akzo-sdd'
$BlockRx = '(?s)[ \t]*' + [regex]::Escape($BlockStart) + '.*?' + [regex]::Escape($BlockEnd) + '[ \t]*\r?\n?'

# VS Code settings.json is JSONC; edit it as text so the user's comments and layout survive.
function Get-VSCodeBlock([string]$text) {
    $helper = Join-Path $ModulesDir 'investigate\scripts\akzo.ps1'
    # Only the helper, only its own commands, and no characters that could chain or substitute another command.
    $rx = '^(powershell|pwsh)(\.exe)? -NoProfile -ExecutionPolicy Bypass -File "?' + ([regex]::Escape($helper) -replace '\\\\', '[\\/]') +
        '"? (home|registry|state|inbox|pick|intake|attach|role|discover|task|graph|sonar|coverage|context|remember|forget|policy|guard|scan|security|branchinfo|tasks|snapshot|profile|review|affected|guidance)\b([^;&|`$<>\r\n"]|"[^"&|`$<>\r\n]*")*$'   # ';' only inside "..." (path lists)
    $rest = [regex]::Replace($text, $BlockRx, '')
    $lines = @()
    if ($rest -notmatch '"chat\.tools\.terminal\.autoApprove"') {
        $lines += '    "chat.tools.terminal.autoApprove": { ' + (ConvertTo-Json -InputObject "/$rx/i") + ': { "approve": true, "matchCommandLine": true } },'
    } else { Write-Warning "VS Code: chat.tools.terminal.autoApprove already exists in $VSCodeSettings; add the akzo helper rule from installation-guide.html yourself." }
    if ($rest -notmatch '"github\.copilot\.chat\.additionalReadAccessPaths"') {
        $lines += '    "github.copilot.chat.additionalReadAccessPaths": ' + (ConvertTo-Json -Compress -InputObject @($AkzoHome, (Get-TasksDir (Read-Config)))) + ','
    } else { Write-Warning "VS Code: github.copilot.chat.additionalReadAccessPaths already exists; add $AkzoHome to it yourself." }
    # VS Code pauses an agent with "Continue?" after 50 requests by default; a full implementation needs more.
    if ($rest -notmatch '"chat\.agent\.maxRequests"') { $lines += '    "chat.agent.maxRequests": 400,' }
    else { Write-Warning "VS Code: chat.agent.maxRequests already set; raise it (e.g. 400) if an Akzo agent stops with 'Continue?'." }
    if (-not $lines) { return '' }
    "    $BlockStart`n" + ($lines -join "`n") + "`n    $BlockEnd`n"
}

function Set-VSCodeSettingsBlock {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([switch]$Remove)
    $text = if (Test-Path $VSCodeSettings) { [IO.File]::ReadAllText($VSCodeSettings) } else { "{`n}`n" }
    $rest = [regex]::Replace($text, $BlockRx, '')
    $block = if ($Remove) { '' } else { Get-VSCodeBlock $text }
    $brace = $rest.IndexOf('{')
    if (-not $block) { $new = $rest }
    elseif ($brace -lt 0) { Write-Warning "VS Code: $VSCodeSettings has no '{'; not changed."; return }
    else {
        $new = $rest.Substring(0, $brace + 1) + "`n" + $block + $rest.Substring($brace + 1).TrimStart("`r", "`n")
        if ($rest.Substring($brace + 1) -match '^\s*\}') { $new = $new -replace ',(\r?\n    ' + [regex]::Escape($BlockEnd) + ')', '$1' }   # nothing follows: no trailing comma
    }
    if ($new -eq $text) { Say "keep    $VSCodeSettings (VS Code settings)"; return }
    if (Test-Path $VSCodeSettings) { Backup $VSCodeSettings }
    Say "$(if ($Remove) { 'clean ' } else { 'update' })  $VSCodeSettings (VS Code settings block)"
    if (-not $DryRun -and $PSCmdlet.ShouldProcess($VSCodeSettings, 'Write VS Code settings')) {
        New-Item -ItemType Directory -Force -Path (Split-Path $VSCodeSettings) | Out-Null
        [IO.File]::WriteAllText($VSCodeSettings, $new, $Utf8)
    }
}

function Read-Manifest {
    if (Test-Path $ManifestPath) { @((Get-Content $ManifestPath -Raw | ConvertFrom-Json).files) } else { @() }
}

# HEAD + porcelain status of every registered repo present on disk.
function Get-RepoSnapshot {
    $snap = @{}
    foreach ($r in @((Read-Config).repos | Where-Object { $_ })) {
        if (-not (Test-GitRepo $r.path)) { continue }
        $snap[$r.id] = ((& git -C $r.path rev-parse HEAD) + "`n" + ((& git -C $r.path status --porcelain=v1 --untracked-files=all) -join "`n"))
    }
    $snap
}

# Desired files: destination path -> bytes. Markdown gets machine paths rendered in.
function Get-DesiredFileMap {
    $render = @{
        '{{MODULES_DIR}}' = ($ModulesDir -replace '\\', '/')
        '{{AKZO_HOME}}'   = ($AkzoHome -replace '\\', '/')
        '{{VERSION}}'     = $SourceVersion
    }
    $files = [ordered]@{}
    $add = {
        param($src, $dest, [switch]$StripVSCodeOnly)
        if ($src -like '*.md') {
            $text = [IO.File]::ReadAllText($src)
            foreach ($k in $render.Keys) { $text = $text.Replace($k, $render[$k]) }
            # Visual Studio documents only name/description/model/tools; keep its copy to documented fields.
            if ($StripVSCodeOnly) { $text = [regex]::Replace($text, "(?m)^$([regex]::Escape($VSCodeOnlyField))\r?\n", '') }
            $files[$dest] = $Utf8.GetBytes($text)
        } else {
            $files[$dest] = [IO.File]::ReadAllBytes($src)
        }
    }
    foreach ($agent in Get-ChildItem (Join-Path $Source 'copilot\agents') -Filter *.agent.md) {
        if ($Target -in 'All', 'VSCode') { & $add $agent.FullName (Join-Path $HomeRoot ".copilot\agents\$($agent.Name)") }
        if ($Target -in 'All', 'VisualStudio') { & $add $agent.FullName (Join-Path $VisualStudioAgentsDir $agent.Name) -StripVSCodeOnly }
    }
    $moduleRoot = Join-Path $Source 'copilot\modules'
    foreach ($f in Get-ChildItem $moduleRoot -Recurse -File) {
        & $add $f.FullName (Join-Path $ModulesDir $f.FullName.Substring($moduleRoot.Length + 1))
    }
    & $add (Join-Path $Source 'VERSION') (Join-Path $ModulesDir 'VERSION')
    $files
}

function Remove-EmptyDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Root)
    if (-not (Test-Path $Root)) { return }
    $dirs = @(Get-ChildItem $Root -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending) + @(Get-Item $Root)
    foreach ($d in $dirs) {
        if (-not (Get-ChildItem $d.FullName -Force) -and $PSCmdlet.ShouldProcess($d.FullName, 'Remove empty directory')) { Remove-Item $d.FullName }
    }
}

function Remove-EmptyAkzoDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    Remove-EmptyDirectory -Root $ModulesDir
    # Earlier versions installed akzo-* skills into the shared skills folder; their files are removed via the old manifest.
    Get-ChildItem (Join-Path $HomeRoot '.copilot\skills') -Directory -Filter 'akzo-*' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-EmptyDirectory -Root $_.FullName }
}

# ---------------------------------------------------------------- verify
if ($Verify) {
    $problems = 0
    $manifest = Read-Manifest
    if (-not $manifest.Count) { Write-Output "NOT INSTALLED: no manifest at $ManifestPath"; exit 1 }
    $installedVersion = if ($saved.version) { $saved.version } else { 'unknown (installed before versioning)' }
    Write-Output "VERSION   installed $installedVersion, this folder $SourceVersion"
    if ($installedVersion -ne $SourceVersion) { Write-Output "OUTDATED: run install.ps1 from this folder to update to $SourceVersion." }
    foreach ($m in $manifest) {
        if (-not (Test-Path $m.path)) { Write-Output "MISSING   $($m.path)"; $problems++ }
        elseif ((Get-FileSha $m.path) -ne $m.sha256) { Write-Output "MODIFIED  $($m.path)"; $problems++ }
        elseif ($m.path -like '*.md' -and ([IO.File]::ReadAllText($m.path) -match '\{\{[A-Z_]+\}\}')) { Write-Output "UNRENDERED $($m.path)"; $problems++ }
    }
    # Isolation: nothing Akzo-specific where Copilot loads customizations for every agent.
    foreach ($d in $SharedSkillDirs) {
        foreach ($s in Get-ChildItem $d -Directory -Filter 'akzo-*' -ErrorAction SilentlyContinue) {
            Write-Output "NOT ISOLATED: shared skill folder $($s.FullName) is offered to every agent. Remove it or re-run install.ps1."; $problems++
        }
    }
    foreach ($d in $SharedInstructionDirs) {
        foreach ($f in Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern 'akzo' -List) {
            Write-Output "WARNING: $($f.Path) mentions Akzo and is applied to every agent (not created by this installer)."
        }
    }
    foreach ($f in @(Get-AkzoMemoryFile)) {
        Write-Output "LEAK: VS Code Copilot memory file $f mentions Akzo; Copilot loads memory into every agent. Run install.ps1 -CleanMemory (or Install-MasterAgent.cmd > Repair)."; $problems++
    }
    foreach ($f in @(Get-LegacyAgentFile)) {
        Write-Output "DUPLICATE: earlier Akzo agent $f is still discovered. Run install.ps1 to migrate it (backed up, then removed)."; $problems++
    }
    foreach ($m in $manifest | Where-Object { $_.path -like '*.agent.md' -and (Test-Path $_.path) }) {
        $text = [IO.File]::ReadAllText($m.path)
        foreach ($ref in [regex]::Matches($text, '[A-Za-z]:/[^"`\s]+/modules/[^"`\s]+\.(md|ps1)') | ForEach-Object { $_.Value } | Sort-Object -Unique) {
            if (-not (Test-Path $ref)) { Write-Output "MISSING MODULE $ref (referenced by $($m.path))"; $problems++ }
        }
    }
    # Repository profiles: every file profiles.json lists is installed, so the helper's 'profile' command can hand it to the agent.
    $pj = Join-Path $ModulesDir 'profiles\profiles.json'
    if (Test-Path $pj) {
        $pdefs = Get-Content $pj -Raw | ConvertFrom-Json
        $plist = @(@($pdefs.shared.skills) + @($pdefs.shared.onDemand.PSObject.Properties | ForEach-Object { $_.Name }) + @($pdefs.profiles | ForEach-Object { @($_.skills) + @($_.sonarRules) }) | Where-Object { $_ })
        $pmiss = @($plist | Where-Object { -not (Test-Path (Join-Path $ModulesDir "profiles\$_")) })
        foreach ($m in $pmiss) { Write-Output "MISSING PROFILE FILE $m"; $problems++ }
        $custom = @(Get-ChildItem (Join-Path $AkzoHome 'profiles-custom') -Recurse -File -ErrorAction SilentlyContinue)
        Write-Output "PROFILES: $(@($pdefs.profiles | ForEach-Object { "$($_.id) ($(@($_.skills).Count) skills + Sonar rules)" }) -join ', '), shared ($(@($pdefs.shared.skills).Count + @($pdefs.shared.onDemand.PSObject.Properties).Count) skills); $($plist.Count - $pmiss.Count) of $($plist.Count) files installed; $($custom.Count) custom file(s) in $AkzoHome\profiles-custom"
    } else { Write-Output 'MISSING PROFILE FILE profiles.json'; $problems++ }
    Write-Output "ISOLATION: helper and templates in $ModulesDir (not a Copilot discovery folder); agent files are the only discovered Akzo files."
    # Visual Studio reads user-level agents (%USERPROFILE%\.github\agents) only from 2026 version 18.5; 2022 has no custom agents.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if ($Target -in 'All', 'VisualStudio' -and (Test-Path $vswhere)) {
        $vsVersions = @(& $vswhere -all -prerelease -property installationVersion 2>$null | Where-Object { $_ })
        $ok = @($vsVersions | Where-Object { [version]$_ -ge [version]'18.5' })
        if ($ok.Count) { Write-Output "VISUALSTUDIO $($ok -join ', ') supports user-level agents (folder: $VisualStudioAgentsDir; must match Tools > Options > GitHub > Copilot)." }
        else { Write-Output "WARNING: Visual Studio 2026 version 18.5 or later not found (installed: $(if ($vsVersions.Count) { $vsVersions -join ', ' } else { 'none' })). Visual Studio shows user-level agents only from 18.5; update it, or use VS Code." }
    }
    $configured = (Test-Path $VSCodeSettings) -and ([IO.File]::ReadAllText($VSCodeSettings)).Contains($BlockStart)
    Write-Output "VSCODE    settings block $(if ($configured) { 'present' } else { 'not added (optional: install.ps1 -ConfigureVSCode)' }) in $VSCodeSettings"
    $desired = Get-DesiredFileMap
    $stale = @($desired.Keys | Where-Object { -not (Test-Path $_) -or (Get-FileSha $_) -ne (Get-Hash $desired[$_]) })
    if ($stale.Count) { Write-Output "OUTDATED: $($stale.Count) file(s) differ from this repository. Run install.ps1 to update." }
    if (Test-Path $Registry) {
        $configProblems = @(Test-Config)
        foreach ($c in $configProblems) { Write-Output "CONFIG    $c"; $problems++ }
        if (-not ($configProblems -match 'not valid JSON')) {
            $cfg = Read-Config
            foreach ($r in @($cfg.repos | Where-Object { $_ })) { Write-Output ("REPO      {0,-22} {1}" -f $r.id, $(if (Test-GitRepo $r.path) { 'ok ' + $r.path } else { 'NOT FOUND ' + $r.path })) }
            $tasks = Get-TasksDir $cfg
            if (Test-Path -LiteralPath $tasks) { Write-Output "TASKS     $tasks  (refined PBIs: <repo-id>\<PBI-ID>\refined-pbi.md)" }
            else { Write-Output "MISSING   tasks folder $tasks. Run install.ps1 to create it."; $problems++ }
        }
    } else { Write-Output "NO REGISTRY at $Registry"; $problems++ }
    Write-Output $(if ($problems) { "VERIFY FAILED: $problems problem(s)." } else { "VERIFY OK: $($manifest.Count) installed file(s) match the manifest." })
    Write-Output 'Note: this checks files on disk only. Confirm discovery in the IDE agent picker (see installation-guide.html).'
    exit $(if ($problems) { 1 } else { 0 })
}

$configProblems = @(Test-Config)
foreach ($c in $configProblems) { Write-Warning "CONFIG: $c" }
if ($configProblems -match 'not valid JSON') { throw "Fix $Registry (not valid JSON) and run again. Nothing was changed." }
$before = Get-RepoSnapshot

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    $manifest = Read-Manifest
    if (-not $manifest.Count) { Write-Output "Nothing to uninstall (no manifest at $ManifestPath)."; exit 0 }
    foreach ($m in $manifest) {
        if (-not (Test-Path $m.path)) { continue }
        if ((Get-FileSha $m.path) -ne $m.sha256) { Backup $m.path }   # edited after install: keep a copy
        Say "remove  $($m.path)"
        if (-not $DryRun) { Remove-Item $m.path -Force }
    }
    foreach ($f in @(Get-LegacyAgentFile)) {
        Backup $f
        Say "remove  $f (earlier Akzo agent)"
        if (-not $DryRun) { Remove-Item -LiteralPath $f -Force }
    }
    if ((Test-Path $VSCodeSettings) -and ([IO.File]::ReadAllText($VSCodeSettings)).Contains($BlockStart)) { Set-VSCodeSettingsBlock -Remove }
    if (-not $DryRun) { Remove-EmptyAkzoDirectory; Remove-Item $ManifestPath -Force }
    $leaks = @(Get-AkzoMemoryFile)
    if ($leaks.Count) { Write-Warning "VS Code Copilot memory still mentions Akzo ($($leaks.Count) file(s)); other agents load it. Remove with: install.ps1 -CleanMemory, or VS Code 'Chat: Clear All Memory Files'." }
    Say "Uninstalled. Kept $AkzoHome (registry, tasks, maps, graphs, backups); delete it manually if no longer needed."
} else {
# ---------------------------------------------------------------- install / update
    Write-Output "Akzo Master SDD Agent $SourceVersion"
    foreach ($req in 'copilot\agents\akzo-master-sdd.agent.md', 'copilot\modules', 'config\repos.example.json', 'VERSION') {
        if (-not (Test-Path (Join-Path $Source $req))) { throw "Source incomplete: $req missing under $Source." }
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Warning 'git not found on PATH: the agent needs git to inspect repositories.' }

    $old = Read-Manifest
    $desired = Get-DesiredFileMap
    $counts = @{ written = 0; unchanged = 0; removed = 0 }
    $touched = New-Object Collections.ArrayList   # files changed by this run, restored on failure
    try {
        foreach ($dest in $desired.Keys) {
            $bytes = $desired[$dest]
            if ((Test-Path $dest) -and (Get-FileSha $dest) -eq (Get-Hash $bytes)) { $counts.unchanged++; continue }
            $was = $old | Where-Object { $_.path -eq $dest } | Select-Object -First 1
            if ($was -and (Test-Path $dest) -and (Get-FileSha $dest) -ne $was.sha256) { Write-Warning "$dest was edited after it was installed; your version is backed up. Keep custom profile rules in $AkzoHome\profiles-custom, which upgrades never touch." }
            if (Test-Path $dest) { Backup $dest }
            Say "write   $dest"
            if (-not $DryRun) {
                [void]$touched.Add($dest)
                New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
                [IO.File]::WriteAllBytes($dest, $bytes)
            }
            $counts.written++
        }
        $obsolete = @($old | Where-Object { -not $desired.Contains($_.path) } | ForEach-Object { $_.path }) + @(Get-LegacyAgentFile | Where-Object { -not $desired.Contains($_) })
        foreach ($p in $obsolete | Sort-Object -Unique) {
            if (-not (Test-Path -LiteralPath $p)) { continue }
            Backup $p
            Say "remove  $p (no longer shipped)"
            if (-not $DryRun) { [void]$touched.Add($p); Remove-Item -LiteralPath $p -Force }
            $counts.removed++
        }
    } catch {
        Write-Warning "Install failed: $($_.Exception.Message) Rolling back $($touched.Count) file(s)."
        foreach ($p in $touched) {
            if ($BackupOf[$p]) { Copy-Item -LiteralPath $BackupOf[$p] $p -Force } elseif (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
        }
        throw "Install failed and was rolled back; the previous installation is unchanged. Cause: $($_.Exception.Message)"
    }
    if (-not (Test-Path $Registry)) {
        Say "create  $Registry (from config\repos.example.json - set your local repository paths)"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $AkzoHome | Out-Null
            Copy-Item (Join-Path $Source 'config\repos.example.json') $Registry
        }
    } else { Say "keep    $Registry" }
    foreach ($r in $AddRepo | ForEach-Object { $_ -split ';' } | Where-Object { $_.Trim() }) { Add-Repository $r.Trim() }   # ';' joins several paths when called through -File
    if ($CleanMemory) {
        foreach ($f in @(Get-AkzoMemoryFile)) { Backup $f; Say "remove  $f (VS Code Copilot memory mentioning Akzo)"; if (-not $DryRun) { Remove-Item -LiteralPath $f -Force } }
    }
    $tasks = Get-TasksDir (Read-Config)
    if (Test-Path -LiteralPath $tasks) { Say "keep    $tasks (tasks folder)" }
    elseif ($configProblems -match '^tasksDir') { Say "skip    tasks folder $tasks (see CONFIG warning)" }
    else {
        Say "create  $tasks (tasks folder)"
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $tasks | Out-Null }
    }
    $inbox = Join-Path $AkzoHome 'inbox'
    if (-not (Test-Path -LiteralPath $inbox)) {
        Say "create  $inbox (inbox: drop refined PBIs here)"
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $inbox | Out-Null }
    }
    Write-Output "Drop refined PBIs (a .md file, or a folder with notes) in: $inbox"
    Write-Output "Refined PBIs go in: $tasks\<repo-id>\<PBI-ID>\refined-pbi.md"
    if ($ConfigureVSCode -or ((Test-Path $VSCodeSettings) -and ([IO.File]::ReadAllText($VSCodeSettings)).Contains($BlockStart))) { Set-VSCodeSettingsBlock }
    if (-not $DryRun) {
        Remove-EmptyAkzoDirectory
        $entries = foreach ($k in $desired.Keys) { [pscustomobject]@{ path = $k; sha256 = Get-Hash $desired[$k] } }
        $commit = try { & git -C $Source rev-parse --short HEAD 2>$null } catch { '' }   # source may be uncommitted
        [pscustomobject]@{ product = 'Akzo Master SDD Agent'; version = $SourceVersion; maintainer = 'Arun RG'; source = $Source; commit = "$commit"; installedAt = (Get-Date).ToString('o'); target = $Target; visualStudioAgentsDir = $VisualStudioAgentsDir; files = @($entries) } |
            ConvertTo-Json -Depth 4 | Set-Content -Path $ManifestPath -Encoding UTF8
    }
    Say ("Done: {0} written, {1} unchanged, {2} removed." -f $counts.written, $counts.unchanged, $counts.removed)
}

# ---------------------------------------------------------------- target repo check
$after = Get-RepoSnapshot
$changed = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique | Where-Object { $before[$_] -ne $after[$_] })
if (-not $before.Count) { Write-Output 'Target repositories: none registered on disk yet (edit repos.json).' }
elseif ($changed.Count) { Write-Warning "Target repositories changed during this run: $($changed -join ', ')"; exit 1 }
else { Write-Output "Target repositories: $($before.Count) registered repo(s) unchanged (HEAD and git status)." }
if (-not $Uninstall -and -not $DryRun) { Write-Output 'Next: restart VS Code / Visual Studio, then pick "akzo-master-sdd" in the Copilot Chat agent picker and type "Start Development".' }
