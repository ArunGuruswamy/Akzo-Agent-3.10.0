# Changelog

Akzo SDD Agent — Developed and maintained by Arun RG. The version is in `VERSION`; `install.ps1 -Verify` shows the installed and available versions.

## 3.4.1 — 2026-10-26 (release candidate)
Release candidate. Supersedes 3.4.0, which was packaged but never distributed and contained the three defects below; the 3.4.0 zip and its checksum were deleted on 2026-10-26 and this entry, with corporate-security-report.html, keeps the defect history. No new features. Corporate readiness: NOT VERIFIED (approvals listed in the report).

**Known limitation, not technically prevented (documented, not fixed):** The developer's authorization is stored in `%USERPROFILE%\.akzo-agent\authorizations.json`. Any process running as that user, including a model with file-edit or terminal tools, can write that file directly. The `authorize` command asks the IDE for confirmation, but the helper cannot tell a command from a direct file write, so the developer's approval is enforced by the IDE's prompts and the agent's instructions, and instructions alone do not enforce approval. Where approval must be enforced, an administrator places a `policy.json` that users cannot write, with `allowDeveloperAttestation` set to `false`: developer statements are then ignored and only listed repositories are processed. G8 reports a developer statement as NOT VERIFIED in every case.

**Security defects found by review and testing, fixed**
- Path traversal through the work-item id: `guard`, `attach`, `role`, and `security` accepted ids such as `..\..` and resolved them to folders outside the tasks folder (a log file could be written there). Ids are now validated wherever a task folder is looked up.
- Sonar token over plain http, and across redirects: the token could be sent unencrypted to an allowed host, or follow a redirect to another place. It is now sent only over https (a loopback server is exempt, for local testing), redirects are not followed, and an insecure host stops before any request (`INSECURE_HOST`; the G8 SonarQube control reports NOT VERIFIED with the reason).
- Memory poisoning: `remember` stored any text, so instruction-like text from a hostile document could be saved as a "verified fact" and loaded in later sessions. Facts that read like instructions to the agent are refused.
- Checked and not reproduced: slow-regex (ReDoS) behaviour of the symbol rules on five hostile line shapes (at most 9 ms each; lines over 400 characters are skipped). Not exhaustive: marked NOT VERIFIED beyond those shapes.

**Performance (measured, `benchmark\results-3.4.1.md`; no check was removed)**
- Sonar setup in `task` reuses the file list the architecture sync already has and skips the machine-tool detection (use the `sonar` command for that): 249 ms -> 44 ms.
- Fingerprint built from an ordered string builder instead of a pipeline; folder-permission checks through .NET instead of `Get-Acl`; one git call fewer when fingerprinting (deleted files come from the same listing); memory-log hit rate read without a pipeline; symbol rules compiled on first use; comment and closing-brace lines skipped before any rule runs.
- Measured with interleaved runs (`scripts\ab-bench.ps1`, 6 rounds, same repository, medians; `benchmark\interleaved-3.4.1.md`): cold `task` 3424 ms (3.4.0) -> 3078 ms (3.4.1), about 10% faster; warm `task` 2249 ms -> 1820 ms, about 19% faster. Against 3.3.0 in the same rounds, 3.4.1 is still +83% cold and +23% warm (3.4.0 was +104% and +52%). An earlier estimate of "about a third faster" came from runs taken one after another while machine load changed and is withdrawn. The G8 preflight, command guard, and memory protection are unchanged.
- Deferred (gain too small for the risk, or adds attack surface): one combined git status call for fingerprinting; extracting symbols lazily on the first `context`; a background indexer process; a real parser such as Tree-sitter (only if measurements show regex extraction missing symbols).

**Tests and process**: 264 checks (5 new: task-id traversal, instruction-like facts, https and redirect handling of the Sonar token with a local stand-in server; the new `ab-bench.ps1` is parse-checked). Each stage ran a strict parse of every script plus a focused smoke test; the full suite and the release validation ran before packaging.

## 3.4.0 — 2026-10-26
Upgrade note: after upgrading, each registered repository needs a one-time authorization (the agent asks; see README, "Upgrading"), and the old `architecture.json` is rebuilt once in the new format. Tasks, `repos.json`, inputs, specs, and notes are untouched.

**Persistent repository memory and retrieval**
- Content fingerprint of every file (git blob id): committed and uncommitted edits, staged and untracked files, deletions, and renames are detected; only changed files are re-read. `architecture.json` (schema 2) adds languages, frameworks from manifests, and inferred patterns; new `symbols.tsv` (types, methods, functions, routes, decorators, imports for C#, TypeScript/JavaScript, Python, Java/Kotlin, Go).
- Verified facts (`facts.json`) with `path:line` evidence and content fingerprints: types architecture, pattern, decision, component, validation, testing, integration, command, convention, pitfall. Stale when evidence changes (dependants too), expired when evidence is gone or retention passes. New commands `remember` and `forget`; secret-looking values are refused. Memory log with hit rate. Corrupt memory files are set aside and rebuilt; writes are atomic.
- New command `context -Query -Mode compact|balanced|deep`: facts first, then ranked files with symbols, linked tests, reference counts, and siblings, within a configurable budget (`retrieval` in `repos.json`); paths beyond the budget are still listed. Agent: four retrieval levels, memory lifecycle, memory update before handover.
- "Implement PBI <id>": a PBI waiting in the inbox is found (`IN_INBOX`) and taken in with the open workspace as the repository.
- **Auto Mode** (Run is its earlier name): authorization record in plan section 0, gates recorded as `Waived (Auto Mode, ...)`, explicit stop list, `resume` understands waived gates. Spec/plan templates: security and performance lines, test level and scenario, requirement -> test -> code matrix.
- Sonar gate also reports the commit of the last server analysis and whether it is behind HEAD.

**Corporate security gate G8 (mandatory, never waived)**
- Preflight: no indexing, extraction, or content output until a policy or the developer's recorded statement authorizes the repository (`policy`, `authorize`; `NEEDS_AUTHORIZATION`, `BLOCKED_BY_POLICY`; fail closed on an unreadable policy; restricted data needs an administrator policy; approved models, allowed hosts, memory disabled, and retention come from the policy). Installer discovery waits for the authorization.
- `guard`: ALLOW / NEEDS_APPROVAL / BLOCK for terminal commands by category (external transfer, remote execution, security-tool tampering, execution policy, registry, elevation, credential access; publishing, dependencies, database, destructive, deployment, analysis upload), logged with redaction. The deny list works by category and behaviour, not by naming attack tools.
- `scan` (secrets, added suppressions and skipped tests, dependency changes on changed lines; specific secret patterns rank above the generic one), `security` (13 controls, report `corporate-security-report.html` in the task's evidence), `purge`. Redaction of secret-looking values in logs, notes, and output; owner-only access on memory and task folders; helper network calls only to allowed hosts and logged.
- `scripts\make-release.ps1` builds the release zip with `release-manifest.json` (SHA-256 of every file) and `.sha256`; `install.ps1` refuses a package with a changed, missing, or unlisted file before writing anything.
- Package report: [corporate-security-report.html](corporate-security-report.html): controls, test evidence, endpoint-protection findings during development, limitations, and the approvals still required.

**Fixes found while testing**
- `inbox` failed on a file without a heading (existing since 1.3.0).
- Dependency detection named only the first package on a changed line; it now compares the manifest's packages with HEAD.
- A connection string with a password was classified as a low-certainty finding because a generic pattern was checked first.
- `guard` failed on commands with inner double quotes under Windows PowerShell 5.1; the pieces are rejoined (the agent is told to use single quotes and to treat a failing guard as blocked).
- Tests: 259 checks (C#, Angular, and Python fixtures; memory, incremental indexing, facts, retrieval, policy, guard, scan, G8, purge, release integrity, syntax-tree audit of the shipped scripts); `make-release.ps1` and `benchmark.ps1` are now parse-checked.

## 3.3.0 — 2026-10-25
- **SonarQube and code rules (agent section 6a):** Sonar sources used strongest first and named in every result: SonarQube MCP tools in chat, read-only helper server queries, Sonar analyzers in the build or lint run, SonarQube for IDE problems, and only on request a scanner upload; otherwise a static review against the code rules, labelled as not a Sonar analysis. Baseline, gate for new code (project gate, or stated defaults: 0 new issues, hotspots listed for review, changed-line coverage >= 80%, new duplication <= 3%), issue-fixing procedure, false positives reported instead of suppressed.
- **Code rules** applied while writing code: complexity and size, unused and dead code, error handling, literals, security, resources and async, state; the repository's own rule configuration wins.
- New helper command `sonar`: Sonar setup of the repository and machine (project key, organization, server, token set or not, pipeline Sonar steps, analyzer packages, coverage tools, rule configuration, exclusions, installed tools), also in the `task` output as `sonar`; with `-Check gate|issues|hotspots|coverage|duplication|rule` a read-only Sonar Web API query. The token is read from `SONAR_TOKEN` and sent only in the request header; branch, pull request, and rule key are validated before use.
- New helper command `coverage`: coverage of the lines changed against HEAD (edits and new files) from Cobertura or LCOV reports: per file coverable, covered, uncovered line ranges, partly covered branches.
- Plan template: Sonar table (source, gate, new issues, hotspots, changed-line coverage, duplication, fixes). Installation guide: SonarQube section and troubleshooting. VS Code auto-approve covers `sonar` and `coverage`.

## 3.2.0 — 2026-10-22
- **Project-agnostic agent:** no project, application, framework, or vendor names in the workflow or templates; stack rules (.NET, serverless functions, GraphQL/generated clients) are profiles that apply only when the repository's architecture index detects that stack.
- **Gated by default:** stops for approval after the gap map (G2), the spec (G3), and the plan (G4); `approve`, `approve all`, or changes. `develop <PBI> end to end` keeps the no-stop Run mode. Approvals are written only after the user's message; the helper reports `gapMapStatus`, `specStatus`, `planStatus`. Limit: the host cannot block file edits, so gates are instruction-enforced.
- **Requirement-to-source and requirement-to-code map (spec §3a):** REQ ids, supporting/contradicting documents, a recorded multi-angle search, EXISTING / REUSABLE / EXTEND / NEW / UNKNOWN with `file:line` and evidence level; NEW only after the full search. Plan tasks carry REQ ids, a per-file action (reuse / modify / new), evidence, and a "reused without change" list; the consistency gate blocks re-implementing existing code.
- **Multi-file input:** `pick` opens a second, multi-select dialog for supporting documents (`-Supporting` without the dialog); new `attach` adds documents later; new `role` corrects a guessed role. Managed copies under `supporting\` (originals untouched, duplicates detected, same names kept as `name-2`). `intake` reports duplicates and renames instead of silently skipping.
- **Input manifest and cache:** `inputs.json` per task (hash, type, role, status, source path, first seen, last changed); `.docx`, `.pdf`, and new `.xlsx` support converted once into `.extract\` keyed by content hash; `task` returns a compact `inputIndex`, `inputIssues` (missing, unsupported, unreadable, duplicate, second primary PBI, rebuilt manifest), and `inputsChanged`. The agent reads supporting documents on demand instead of all at once.
- **Architecture knowledge:** `maps\<repo>\architecture.json` and `component-index.tsv` from `git ls-files`, rebuilt only when HEAD moves (new `discover` to force); built during *Add repository*; per repository, never mixed. Verified facts keep going to `maps\<repo>.md`, updated incrementally.
- `task` output is compact JSON. Auto-approve rule covers `attach`, `role`, `discover`, and allows `;` only inside a quoted path list. `Verify` checks the Visual Studio version (18.5+ for user-level agents).

## 3.1.0 — 2026-10-21
- **Ambiguity scan** before the spec is final: eight categories rated Clear / Partial / Missing; at most 5 highest-impact questions; anything nobody can answer is marked `[NEEDS CLARIFICATION]` instead of guessed; answered questions are never asked again.
- **Requirement quality and readiness:** every AC measurable and testable, no placeholders; spec records Ready / Ready with open questions / Not ready.
- **Entities and state transitions** table in the spec (identity, validation, from -> to, trigger, rule), e.g. initial status and version on creation.
- **Consistency gate (section 4a)** between plan and code: coverage (AC without task, task without AC), duplication, ambiguity, inconsistency, guidance conflicts, with severities; CRITICAL/HIGH fixed before implementation; Plan mode includes it. Plan template section 1a records the findings.
- **Optional read-only subagents** (VS Code `runSubagent`) for parallel investigation; never for edits.

## 3.0.0 — 2026-10-21
- **One agent:** `akzo-sdd` merged into `akzo-master-sdd` and no longer shipped; upgrades remove the old agent files (manifest, or an Akzo agent file found without one), after a backup.
- **One-click setup:** `Install-MasterAgent.cmd` (Install/Upgrade, Repair, Verify, Uninstall, Add repository), `Uninstall-MasterAgent.cmd`, `Start-Development.cmd`. `install.ps1` gains `-AddRepo`, `-CleanMemory`, rollback on a failed write, and short backup names for paths beyond MAX_PATH.
- **Start Development:** the agent runs the new helper command `pick`, which opens a Windows file dialog, converts .md/.txt/.docx (.pdf with pdftotext) into `<inbox>\<name>\refined-pbi.md` with the original under `source\`, and detects PBI number and title; when number, title, and repository are clear it starts without questions.
- **Autonomous quality loop:** quality baseline before the first edit; Build → Test → Analyze → Fix → Re-validate until 0 build errors, 0 newly failing tests, 0 new warnings/Sonar issues in changed files; gate integrity (no suppressions, skipped tests, placeholders, or reworded ACs); evidence kinds; 3-attempt limit; status DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT. Run is the default mode.
- **Decisions:** mechanical (silent), taste (decided and listed for review), user decision (asked once per phase). Value completeness for changed statuses/enums, scope lock and scope check, root-cause debugging with regression test, command safety list.
- **Agent isolation fix:** VS Code loads Copilot user memory into every agent; the agent never writes its rules there, `-Verify` reports Akzo text in user/repository memory and the VS Code `prompts` folder, Repair cleans it.
- Plan template: baseline vs final quality table. GUI test `scripts\test-gui.ps1`.

## 2.0.0 — 2026-10-20
- New agent `akzo-master-sdd`: the complete akzo-sdd workflow plus an engineering-skills section (S1-S19) applied per phase — requirement sharpening, source-driven decisions, Clean Architecture/CQRS design review, contract design, C#/.NET coding, Azure Functions, DAB GraphQL/StrawberryShake, test-driven slices, incremental delivery, systematic debugging, security, performance, observability, simplification, quality-bar guard, doubt pass, five-axis review, git hygiene, decision records — and a Debug mode.
- Installer ships every agent in `copilot/agents` to both IDEs; `akzo-sdd` is unchanged and still installed.
- Debug mode never bisects or checks out other commits; without a PBI it reports in chat instead of a plan. Docs and installer messages name both agents.

## 1.3.0 — 2026-10-20
- Guided start: say "start" to pick a refined PBI from the inbox (`%USERPROFILE%\.akzo-agent\inbox`). The agent asks once for item, PBI number, title, repository, and mode, copies the PBI and notes into the task folder, names the spec folder from the title, and starts.
- Accuracy: naming and structure are taken from 2-4 sibling features (conventions table in the spec); existing GraphQL operations are reused before new ones are added; an integration check (registered, referenced, used, no duplicates, no new warnings) runs before handover.
- Continuous execution in Run mode; new Align mode for reviewing and fixing an existing implementation.
- `-ConfigureVSCode` also raises `chat.agent.maxRequests` to 400 (VS Code pauses with "Continue?" after 50 by default).
- Agent version shown in the agent, the installer output, the manifest, and `-Verify`.

## 1.2.0 — 2026-10-20
- Whole workflow inside the agent file (no workflow-file reads); one helper call starts or resumes a task.
- `-ConfigureVSCode`: auto-approve rule for the helper only, read access to the Akzo folders.
- Per-repository `specsDir` (e.g. `src/.github/specs/<Feature>/`); repository skills and instructions discovered and followed; reference implementation (e.g. CDMS -> DAB) mapped and mirrored; questions in one batch with options.

## 1.1.0 — 2026-10-19
- Refined-PBI intake: `<tasks>\<repo-id>\<PBI-ID>\refined-pbi.md`, change detection against a baseline, resume, configurable `tasksDir`.

## 1.0.0 — 2026-10-19
- First release: akzo-sdd custom agent for VS Code and Visual Studio 2026, installer with dry run, verify, uninstall, and backups.
