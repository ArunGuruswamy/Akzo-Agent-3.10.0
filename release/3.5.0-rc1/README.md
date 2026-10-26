# Akzo Master SDD Agent 3.5.0 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.5.0.zip` | The package: the same 29 files as the source at tag `v3.5.0-rc1`, plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ. |
| `Akzo-Agent-3.5.0.zip.sha256` | Checksum of the zip |

SHA-256 of the zip: `3EA041B1C74DADAEF3F79CE67CEAF1EF301A8D19F8984E4486DDA75F53E42F90`

Check it with `Get-FileHash Akzo-Agent-3.5.0.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

What changed: every PBI is its own task (fresh intake, its own spec folder, no inherited approvals), a branch check before development, and architecture memory kept apart from PBI progress. See `CHANGELOG.md`.

Validation: 287 regression checks passed, 13 GUI checks passed, and 14 of 14 release checks run on this zip (integrity, install, upgrade from 3.3.0 and 3.4.1, rollback, uninstall, full suite from the package).

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html` and `CHANGELOG.md` in the repository root for results, limitations, and the approvals still required. The 3.4.1 demo deck in `release/3.4.1-rc1` has not been updated for 3.5.0.
