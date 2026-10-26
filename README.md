# Akzo Master SDD Agent

**Akzo SDD Agent — Developed and maintained by Arun RG** · Version: see [VERSION](VERSION) and [CHANGELOG.md](CHANGELOG.md)

One GitHub Copilot custom agent, **`akzo-master-sdd`**, for spec-driven development in any registered repository. It discovers the repository's architecture, maps every requirement of a refined PBI (plus your supporting documents) to existing code as **EXISTING / REUSABLE / EXTEND / NEW / UNKNOWN**, writes `spec.md` and `plan.md`, implements test first, and validates build, tests, and analyzers. It stops for your approval after the gap map, the spec, and the plan. It runs in Copilot Chat in **VS Code** and **Visual Studio 2026** (18.5+ for user-level agents), and only when you select it. Nothing in the agent is tied to a particular project, framework, or organization: stack-specific rules apply only when the repository's architecture index detects that stack.

> **Release candidate.** Version 3.4.1 is a release candidate. Corporate readiness is **NOT VERIFIED**: see [corporate-security-report.html](corporate-security-report.html) for what was tested, the limitations, and the approvals still required.
>
> **Known limitation:** The developer's authorization is stored in `%USERPROFILE%\.akzo-agent\authorizations.json`. Any process running as that user, including a model with file-edit or terminal tools, can write that file directly. The `authorize` command asks the IDE for confirmation, but the helper cannot tell a command from a direct file write, so the developer's approval is enforced by the IDE's prompts and the agent's instructions, and instructions alone do not enforce approval. Where approval must be enforced, an administrator places a `policy.json` that users cannot write, with `allowDeveloperAttestation` set to `false`: developer statements are then ignored and only listed repositories are processed. G8 reports a developer statement as NOT VERIFIED in every case.

## Four steps
1. **Install:** double-click **`Install-MasterAgent.cmd`** → *Add repository…* (choose your local clone; its architecture is indexed right away) → *Install / Upgrade*.
2. **Open** VS Code or Visual Studio 2026 (restart it after installing) and select **akzo-master-sdd** in the Copilot Chat agent picker.
3. **Type `Start Development`.** A Windows file dialog opens (it may appear behind the IDE): choose the refined PBI (`.md`, `.txt`, `.docx`; `.pdf` when `pdftotext` is installed). A second dialog lets you select any number of supporting documents at once (business rules, specs, API contracts, schemas, test cases, sample data, diagrams…); Cancel skips it.
4. **Review at three gates.** The agent stops after the **gap map** (what exists, what is reused, extended, or new), after the **spec**, and after the **plan**. Reply `approve` to continue, `approve all` to let it finish without further stops, or describe changes. After plan approval it implements, builds, tests, and reports.

Alternative to step 3: double-click **`Start-Development.cmd`** (same two dialogs), then type `start` in Copilot Chat (the launcher puts `start` on the clipboard). Add documents later with `attach <files> to <PBI>`.

| Launcher | What it does |
|----------|--------------|
| `Install-MasterAgent.cmd` | Window with **Install / Upgrade**, **Repair**, **Verify**, **Uninstall**, and **Add repository…** |
| `Start-Development.cmd` | Dialogs for the PBI and supporting documents → queued in the inbox → tells you the next step |
| `Uninstall-MasterAgent.cmd` | Asks, then removes only installer-owned files (keeps repos.json, tasks, inbox, specs, knowledge, backups) |

Command-line equivalents (no window): `scripts\Install-MasterAgent.ps1 -Action Install|Repair|Verify|Uninstall -NoGui [-Repo <path>]`, or the engine `scripts\install.ps1` (`-DryRun`, `-Verify`, `-Uninstall`, `-AddRepo <path>`, `-CleanMemory`, `-ConfigureVSCode`, `-Target VSCode|VisualStudio`, `-VisualStudioAgentsDir`).

## Chat commands
| You type | Mode | What happens |
|----------|------|--------------|
| `Start Development` | Gated (default) | Dialogs for PBI + supporting documents, then the run with stops at G2 (gap map), G3 (spec), G4 (plan) |
| `start` | Gated | Takes the newest item in the inbox (after `Start-Development.cmd`) |
| `develop 305912` | Gated | Same, for a PBI already in the tasks folder |
| `implement PBI 305912` | Gated | Finds the PBI (task folder or inbox), uses the open workspace as the repository when it is registered, loads repository memory, then as `develop` |
| `implement PBI 305912 in Auto Mode` | Auto | The whole PBI in one go inside the scope you authorize: analysis, gap map, spec, plan, test-first implementation, tests, analyzers/Sonar, memory update, G8 security gate, handover. Stops only for business ambiguity, destructive or production actions, permission changes, new dependencies, and anything outside the scope |
| `develop 305912 end to end` | Auto | The earlier name for Auto Mode |
| `plan 305912` | Plan | Gap map, spec, plan, and consistency gate; stops before any code |
| `attach C:\docs\notes.docx to 305912` | — | Adds supporting documents to an existing task |
| `review and align 305912` | Align | Code exists: compares it with siblings and the gap map, fixes deviations, validates |
| `debug <symptom>` | Debug | Root-cause fix with a regression test |
| `resume 305912` | Resume | Continues from the first gate neither approved nor waived, or from "Remaining" in plan.md |

## How a PBI is analyzed
1. **Inputs:** the refined PBI is authoritative. Supporting documents are copied to the task (`supporting\`, originals untouched; duplicates detected; same names never overwritten) and listed in `inputs.json` with hash, type, guessed role (correct it with `role`), status, and source path. `.docx`, `.pdf` (with `pdftotext`), and `.xlsx` are converted once into cached text keyed by content hash; images and unknown formats are listed, never guessed at. The agent reads only the sections it needs.
2. **Architecture knowledge:** a per-repository index from `git ls-files` (stack, folders, files by component role: entry points, commands, queries, handlers, validators, services, repositories, models, contracts, UI, tests…), rebuilt only when HEAD moves; plus verified facts the agent records per repository and reuses in later PBIs.
3. **Gap map (G2):** every requirement gets an id (REQ-n), the documents that support or contradict it, a recorded multi-angle code search, and a class: EXISTING, REUSABLE, EXTEND, NEW (only after the full search), or UNKNOWN (not enough evidence), with `file:line` evidence and an evidence level (source, test, run). Conflicts between documents become questions, never silent choices.
4. **Spec (G3):** ambiguity scan, at most 5 questions, measurable acceptance criteria linked to requirements, existing behavior kept as "no change", entities and state transitions.
5. **Plan (G4):** tasks with requirement ids and a per-file action (reuse / modify / new) following the discovered folders and naming; a "reused without change" list; a consistency gate that blocks re-implementing anything classified EXISTING, REUSABLE, or EXTEND.
6. **Implement and validate:** test first; build → test → analyzers/Sonar → fix until 0 build errors, 0 newly failing tests, 0 new issues in changed files; never suppressions or skipped tests.
6a. **SonarQube and code rules:** code is written to a built-in rule set (complexity, unused code, error handling, literals, security, resources, async) and checked against the project's Sonar quality gate using the strongest source available: SonarQube MCP tools in chat, read-only server queries through the helper (gate, issues, hotspots, coverage, duplication, rule details; token from `SONAR_TOKEN`, never shown), Sonar analyzers in the build, or SonarQube for IDE. Coverage of changed lines is measured from the repository's own Cobertura or LCOV reports. Without a server it uses stated defaults (0 new issues, hotspots listed for review, changed-line coverage ≥ 80%, new duplication ≤ 3%). It never uploads an analysis unless asked. Setup: [installation-guide.html#sonar](installation-guide.html#sonar).
7. **Handover (G5):** requirement → class → acceptance criterion → evidence table, baseline vs final counts, open questions, proposed commit message. It never commits or pushes.

## Repository memory (3.4.0)
Per repository, under `%USERPROFILE%\.akzo-agent\maps\<repo-id>\`, never mixed between repositories and never uploaded:
- `architecture.json`, `component-index.tsv`, `symbols.tsv`: languages, frameworks (from manifests), inferred patterns, files by role, and the types, methods, functions, routes, and imports of C#, TypeScript/JavaScript, Python, Java/Kotlin, and Go (regex extraction, not a parser: good for finding and ranking, never proof).
- Every file is fingerprinted by content (git blob id), so committed and uncommitted edits, staged and untracked files, deletions, and renames are noticed on the next call and only the changed files are re-read.
- `facts.json`: verified facts (end-to-end patterns, reusable components, validation and testing conventions, integrations, decisions, commands, pitfalls), each with `path:line` evidence and the evidence's content fingerprint. A fact turns **stale** when its evidence changes (and so do facts that depend on it), and **expires** when the evidence file is gone or the policy's retention period passes. The agent must revalidate a stale fact before using it. Values that look like secrets are refused.
- `context -Query "<terms>" [-Mode compact|balanced|deep]`: ranked files with key symbols, linked tests, and matching facts within a size budget (balanced by default; set `retrieval.mode` and `retrieval.budgets` in `repos.json`). Ranked by deterministic matching, not proof: the agent reads the cited lines.
- Unreadable memory is set aside as `*.corrupt-<time>` and rebuilt. `purge -Repo <id> -Confirmed` deletes a repository's memory.

## Corporate security gate (G8, 3.4.0)
Mandatory in every mode, including Auto Mode; never waived. See [corporate-security-report.html](corporate-security-report.html) for the controls, test evidence, limitations, and the approvals still required.
- **Preflight (technical):** before a repository is indexed, documents are extracted, or content is output, the helper requires an authorization: an administrator policy (`%ProgramData%\AkzoAgent\policy.json`, or `policy.json` in the Akzo folder) that lists the repository, or the developer's own recorded statement (`authorize`, with the reference they hold and the data classification). Without one, `task` returns `NEEDS_AUTHORIZATION`; an unreadable or forbidding policy returns `BLOCKED_BY_POLICY`. Restricted data needs an administrator policy. A developer statement is reported as NOT VERIFIED, never as corporate approval.
- **Command guard:** the agent checks every non-helper terminal command with `guard`: ALLOW, NEEDS_APPROVAL (git commit/push, dependency installs, deployments, database changes, destructive deletes, analysis uploads), or BLOCK (external transfer, remote code execution, security-tool tampering, execution-policy and registry changes, elevation, credential access). A blocked command is never run and no approval releases it. Checks are logged to the task's evidence with secrets redacted. The guard is run by the agent: Copilot offers no hook that forces it, so the log shows what the agent reported (see the report's limitations).
- **Network:** the helper's only network call is the read-only Sonar query, and only to a host the policy or authorization lists.
- **Data protection:** secret-looking values are redacted from logs, notes, and output; memory and task folders are restricted to the owner, SYSTEM, and Administrators; retention and `memory: disabled` come from the policy.
- **Gate (`security -Id <PBI>`):** 13 controls with PASS / FAIL / NOT VERIFIED / NOT APPLICABLE and the evidence for each, written to `<task>\evidence\corporate-security-report.html`. FAIL blocks the handover; NOT VERIFIED allows DONE_WITH_CONCERNS at best; only PASS allows DONE. Automated verification is never corporate approval.
- **Release integrity:** `scripts\make-release.ps1` builds the zip with `release-manifest.json` (SHA-256 of every file) and a `.sha256` file; `install.ps1` refuses a package whose files differ. Hashes show the package is unchanged, not who made or approved it.

**Approval limits:** the gates are enforced by the agent's instructions and by the statuses recorded in spec.md and plan.md (the helper reports them on every call, so a resumed session respects them). Copilot offers no hook that blocks file edits, so the IDE cannot technically stop a model error or an explicit instruction from skipping a gate.

## Where files go
| What | Where |
|------|-------|
| Chosen PBI and supporting documents (before intake) | `%USERPROFILE%\.akzo-agent\inbox\<name>\` (`refined-pbi.md`, `source\`, `supporting\`) |
| Task workspace | `%USERPROFILE%\.akzo-agent\tasks\<repo-id>\<PBI-ID>\` (`refined-pbi.md`, `supporting\`, `inputs.json`, `.extract\`, `evidence\`) |
| spec.md, plan.md | `<repo>\<specsDir>\<FeatureName>\` when the repo has a spec folder, otherwise in the task workspace |
| Project knowledge | `%USERPROFILE%\.akzo-agent\maps\<repo-id>.md` (verified facts) and `maps\<repo-id>\architecture.json`, `component-index.tsv` |
| Code changes | your repository, uncommitted, visible in Git Changes |
| Registry, backups | `%USERPROFILE%\.akzo-agent\` |

## Upgrading from 3.3.0 or earlier
Run **Install / Upgrade** (or `install.ps1`) from the new package; nothing else is needed for tasks, `repos.json`, inputs, or specs. Two things change, both by design:
1. **Authorize once per repository.** The first time the agent works on a registered repository after the upgrade, `task` returns `NEEDS_AUTHORIZATION` and the agent asks whether you hold an authorization (reference and data classification); it records your answer. Administrators can instead place `policy.json` (see the report). *Add repository* indexes a new repository only after it is authorized.
2. **Memory is rebuilt once.** The old `architecture.json` is replaced by the new format on first use; your notes in `maps\<repo-id>.md` are kept and shown as unverified hints. Roll back by installing the previous package's zip over this one (backups of replaced files are in `%USERPROFILE%\.akzo-agent\backups\`).

## What install, upgrade, and repair do
- Copies the agent to `%USERPROFILE%\.copilot\agents` (VS Code) and `%USERPROFILE%\.github\agents` (Visual Studio 2026), and the helper and templates to `%USERPROFILE%\.akzo-agent\modules`.
- **Idempotent:** unchanged files are skipped; a rerun never duplicates anything. **Repair** restores missing or modified files and cleans leaked Akzo text from Copilot memory.
- **Upgrade/migration:** files from earlier versions that are no longer shipped are removed via the install manifest; an older `akzo-sdd` agent found without a manifest entry is removed too (only if it is an Akzo agent file). Existing tasks keep working: their manifest is built on the next `task` call.
- **Backups and rollback:** every file replaced or removed is first copied to `%USERPROFILE%\.akzo-agent\backups\<timestamp>\` (deep paths listed in `index.txt`). If a write fails, every file changed by that run is restored.
- **Repositories:** *Add repository…* (or `-AddRepo`) registers a Git clone in `repos.json` (backed up first), uses an existing spec folder (`openspec/changes`, `src/.github/specs`, `.github/specs`, `docs/specs`, `specs`), and builds its first architecture index. Nothing is written into your repositories by the installer.
- **VS Code (optional, on by default in the window):** a marked settings block auto-approves only the helper's own commands (a `;` is allowed only inside a quoted path list), grants read access to the Akzo folders, and raises the agent step limit to 400.
- `Verify` also warns when Visual Studio 2026 18.5+ (needed for user-level agents) is not installed.

## Other agents keep their normal behavior
The agent's rules live only in its agent file. Nothing is written to `AGENTS.md`, `.github/copilot-instructions.md`, `.github/instructions`, prompt files, or skills: Copilot applies those to **every** agent. If another agent still behaves like the Master agent: (1) **Copilot memory** — VS Code loads the first 200 lines of user memory into every agent; **Repair** (`-CleanMemory`) removes memory files that mention Akzo after a backup, `Verify` reports them as `LEAK`; (2) **same chat** — switching agents keeps the history, start a new chat; (3) **leftover agent files** — `Verify` reports them, Install migrates them.

## Develop and test this package
- `scripts\make-release.ps1` — builds `Akzo-Agent-<version>.zip` with `release-manifest.json` and a `.sha256` file. `scripts\ab-bench.ps1` — interleaved timing of up to three helper versions on one repository (results in `benchmark\interleaved-3.4.1.md`). `scripts\benchmark.ps1` — timing of the previous package against this one on a generated repository (results in `benchmark\results-3.4.1.md`; single-run cold and warm figures are superseded by the interleaved ones; model tokens and Copilot interactions are not measurable here).
- `scripts\test.ps1` — 264 checks in a temporary profile (repository memory on C#, Angular, and Python fixtures, incremental indexing, facts, retrieval, G8 preflight, command guard, scanning, policy, purge, release integrity, Sonar against a local stand-in server, and changed-line coverage included): static agent checks (incl. project-agnostic wording, gates, gap map), install, upgrade/migration, rerun, repair, rollback, AddRepo with first discovery, memory-leak cleanup, VS Code settings and auto-approve rule, intake, `pick` with supporting documents, `attach`, `role`, manifest, duplicate/missing/unsupported/second-primary detection, `.docx`/`.xlsx` extraction and cache reuse, change detection, interrupted-processing recovery, architecture index (roles, refresh on new commit, per-repository isolation), launchers, uninstall. Never touches your real profile.
- `scripts\test-gui.ps1` — drives the real windows through the `.cmd` launchers (PBI dialog, multi-select supporting dialog, setup window, uninstall confirmation) in a temporary profile. Needs a desktop session.

## Ownership and licensing
- Original implementation by Arun RG. No third-party code, prompts, or documentation are bundled; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- License: **not yet selected.** It will be chosen once ownership and organizational requirements are confirmed. Until then, no license is granted.
