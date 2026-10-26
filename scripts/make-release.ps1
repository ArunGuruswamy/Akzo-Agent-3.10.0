<#
.SYNOPSIS
  Builds the release package: Akzo-Agent-<version>.zip with release-manifest.json (SHA-256 of every file) inside, and
  Akzo-Agent-<version>.zip.sha256 beside it.
.DESCRIPTION
  install.ps1 checks release-manifest.json before installing and refuses a package whose files differ, are missing, or
  are not listed. Publish the .sha256 value through a trusted channel so recipients can check the zip itself
  (Get-FileHash <zip> -Algorithm SHA256). Hashes show that the package is unchanged; they do not show who produced or
  approved it. Where the organization requires it, sign the scripts with its code-signing certificate first
  (Set-AuthenticodeSignature) and keep the signed files in the package. Entries use forward slashes, so the zip
  extracts correctly on every platform.
.EXAMPLE
  .\scripts\make-release.ps1                    # writes ..\Akzo-Agent-<version>.zip next to the package folder
  .\scripts\make-release.ps1 -OutDir C:\releases
.NOTES
  Akzo SDD Agent — Developed and maintained by Arun RG
#>
param([string]$OutDir = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$Source = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $Source 'VERSION') -TotalCount 1).Trim()
$zip = Join-Path $OutDir "Akzo-Agent-$version.zip"
if (Test-Path $zip) { throw "$zip already exists; remove it or choose -OutDir (a release is never overwritten silently)." }
$files = @(Get-ChildItem $Source -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne 'release-manifest.json' -and $_.FullName.Substring($Source.Length + 1) -notmatch '^release\\' } | Sort-Object FullName)   # earlier published releases (release\) are not part of a package
$entries = @($files | ForEach-Object { [pscustomobject][ordered]@{ path = $_.FullName.Substring($Source.Length + 1) -replace '\\', '/'; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; bytes = $_.Length } })
$manifest = [pscustomobject][ordered]@{
    product = 'Akzo SDD Agent'; maintainer = 'Arun RG'; version = $version; built = (Get-Date).ToString('s'); builtBy = "$env:USERDOMAIN\$env:USERNAME"
    signature = (@($files | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { "$($_.Name): $((Get-AuthenticodeSignature -LiteralPath $_.FullName).Status)" }) -join '; ')
    files = $entries
}
$z = [IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($f in $files) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $f.FullName, ($f.FullName.Substring($Source.Length + 1) -replace '\\', '/'), 'Optimal') }
    $e = $z.CreateEntry('release-manifest.json', 'Optimal'); $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding($false)))
    try { $w.Write(($manifest | ConvertTo-Json -Depth 4)) } finally { $w.Dispose() }
} finally { $z.Dispose() }
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
[IO.File]::WriteAllText("$zip.sha256", "$hash  $(Split-Path $zip -Leaf)`n")
Write-Output "release ${version}: $zip ($($entries.Count) files + release-manifest.json)"
Write-Output "SHA-256 $hash (also in $zip.sha256)"
