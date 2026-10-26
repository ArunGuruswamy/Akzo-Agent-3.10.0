# Akzo Master SDD Agent 3.4.1 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.4.1.zip` | The package: the same 29 files as the source at tag `v3.4.1-rc1`, plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ. |
| `Akzo-Agent-3.4.1.zip.sha256` | Checksum of the zip |
| `Akzo-Master-SDD-Agent-3.4.1-demo.pptx` | Demo deck. Built without a renderer: open it once in PowerPoint before presenting. |

SHA-256 of the zip: `4B7E1A5697053D0AA96F5394F286F78C2749CF127D5FE8C2CFEDC73C55FAF171`

Check it with `Get-FileHash Akzo-Agent-3.4.1.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html` and `CHANGELOG.md` in the repository root for results, limitations, and the approvals still required.
