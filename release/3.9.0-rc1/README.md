# Akzo Master SDD Agent 3.9.0 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.9.0.zip` | The package: the same 56 files as the source at tag `v3.9.0-rc1` (built from a clean export of the tag), plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ or whose manifest names another version. |
| `Akzo-Agent-3.9.0.zip.sha256` | Checksum of the zip |

SHA-256 of the zip: `DF281848C1E981A9B19185B6A4F6391799E715BFC371802DA510D49135EEB59F`

Check it with `Get-FileHash Akzo-Agent-3.9.0.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

What changed: the setup window. Repositories are shown in a table with Add, Edit, Remove, Open in Explorer, Validate, and Refresh; a path can be typed, pasted, or browsed. Removing a repository removes only its registration, never the folder. A new Agent Installation Status panel shows each check as Verified, Warning, Failed, Not Applicable, or Not Checked; whether the agent appears in the IDE's picker is always Not Checked, with manual steps. The agent's description no longer contains `: `, which strict YAML parsers reject. See `CHANGELOG.md`.

Validation: 357 regression checks and 14 window checks passed; the zip installed into an empty profile and verified (package integrity OK, 21 of 21 profile files, version 3.9.0 everywhere, no failed check).

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html`. Whether the 3.8.0 description caused the agent to be missing in Visual Studio is NOT VERIFIED (no Visual Studio 2026 18.5+ was available); run *Verify Installation* on the affected machine.
