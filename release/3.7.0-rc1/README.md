# Akzo Master SDD Agent 3.7.0 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.7.0.zip` | The package: the same 56 files as the source at tag `v3.7.0-rc1`, plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ. |
| `Akzo-Agent-3.7.0.zip.sha256` | Checksum of the zip |

SHA-256 of the zip: `345420BF3E5F2978E6F1D8F1F6BEE47E6534D56A06ADB4711E89B9E3C5E38D8D`

Check it with `Get-FileHash Akzo-Agent-3.7.0.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

What changed: DAB and CDMS repository profiles with pre-PR review (3.6.0, never released separately), then lazy profile loading, cached detection, exact-symbol lookup, staged test selection (`affected`), business-rule branch coverage, and reusable PR review categories (3.7.0). See `CHANGELOG.md`.

Validation: 328 regression checks passed; the zip installed into an empty profile and verified (integrity, 21 of 21 profile files, helper and agent at 3.7.0); helper benchmark against 3.6.0 in `benchmark/perf-3.7.0.md`. GUI checks were not rerun (no window or dialog code changed). Upgrade from 3.5.0 by zip was not run separately; the suite's upgrade checks passed.

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html` and `benchmark/verification-3.7.0.md`. No live Copilot session, DAB/CDMS repository, or SonarCloud project was available.
