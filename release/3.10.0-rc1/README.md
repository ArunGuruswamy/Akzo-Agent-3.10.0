# Akzo Master SDD Agent 3.10.0 release candidate

Akzo SDD Agent — Developed and maintained by Arun RG

| File | What it is |
|---|---|
| `Akzo-Agent-3.10.0.zip` | The package: the same 57 files as the source at tag `v3.10.0-rc1` (checked file by file against the tag), plus `release-manifest.json` (SHA-256 of every file). `install.ps1` refuses a package whose files differ or whose manifest names another version. |
| `Akzo-Agent-3.10.0.zip.sha256` | Checksum of the zip |

SHA-256 of the zip: `FDDB7938899059037C1A5CC457A5AEBE476143A4EFC520F03871117BE5785E8A`

Check it with `Get-FileHash Akzo-Agent-3.10.0.zip -Algorithm SHA256`. A hash shows the file is unchanged since it was built, not who built or approved it.

What changed: gates and tasks are shown by name (gate titles and explanations in `modules/plan/assets/workflow.json`; task titles from `plan.md`). At each approval stop the agent offers Approve, Request changes, or Custom response, and the helper's new `decide` command records the decision with the user, time, and a hash of the document decided on. Task statuses keep implementation apart from verification. `branchinfo` reports staged, unstaged, untracked, and conflicted files and a merge or rebase in progress; `review` flags empty generated client files. See `CHANGELOG.md`.

Validation: 370 regression checks and 14 window checks passed (run from Windows PowerShell). The zip installed into an empty profile and verified (package integrity OK, version 3.10.0 everywhere); an install made from the 3.9.0 zip upgraded and verified with existing task files unchanged.

Status: release candidate. Corporate readiness is NOT VERIFIED; see `corporate-security-report.html`. How Copilot presents the approval choices in a live session, and the PBI 305912 scenario on the DAB and CDMS repositories, are NOT VERIFIED (not available on this machine).
