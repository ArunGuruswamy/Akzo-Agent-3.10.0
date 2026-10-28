# Akzo Master SDD Agent 3.8.0 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.8.0.zip` | The package: the same 56 files as the source at tag `v3.8.0-rc1`, plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ. |
| `Akzo-Agent-3.8.0.zip.sha256` | Checksum of the zip |

SHA-256 of the zip: `DB07129AE3B0548B15E000FB474166EFF81F5466D02E0C918558D037B62D39A2`

Check it with `Get-FileHash Akzo-Agent-3.8.0.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

What changed: task routing. `start` offers Fix Issue, Refactor, New Development / PBI, Review / Analyze, and Custom Task; a task given directly is routed without the menu. Fix Issue and Refactor read only the affected code, its tests, and the Sonar rules (`profile -Task fix|refactor`) and end with Issue / Cause / Fix / Verification / Status. A new read-only `guidance -Repo <id>` command shows which repository instruction files make Copilot read which documents, and for which agents. See `CHANGELOG.md`.

Validation: 338 regression checks passed; the zip installed into an empty profile and verified (integrity, 21 of 21 profile files, helper and agent at 3.8.0). GUI checks were not rerun (no window or dialog code changed).

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html`. No live Copilot session, DAB/CDMS repository, or SonarCloud project was available, so the routing cases and the S1200 regression case in `benchmark/agent-evaluations.md` (17-27) are not verified.
