# Repository development profiles

Akzo SDD Agent — Developed and maintained by Arun RG

The agent file stays project-agnostic. Repository-specific rules live here and are read only after the helper has
identified the repository. Each skill is a `guide.md` in its own folder, without YAML front matter and not named `SKILL.md`, so
no skill scanner can discover it; the helper hands the files to the agent:

```
akzo.ps1 profile -Repo <id>              # DETECTED / AMBIGUOUS / UNCERTAIN / NO_PROFILE, with the evidence
akzo.ps1 profile -Repo <id> -Key cdms    # confirm a profile when several fit (its solution must be in the repository)
akzo.ps1 review  -Repo <id> -Base main   # pre-PR review of the change against the profile's rules
```

| Profile | Repository | Selected only when this solution is in the repository |
|---|---|---|
| `dab` | AN.ColorAppsAzure.BL | `AN.ColorAppsAzure.BL.sln` |
| `cdms` | ColorDMS | `AN.ColorAppsAzure.BL.ColorDMS.sln` |

- **Isolation:** the helper returns the shared skills plus the files of exactly one profile. The other profile's files
  are listed under `neverLoad`, and `guard -Repo <id>` refuses a `dotnet` command that names a solution which is not in
  the repository or belongs to the other profile.
- **Not Copilot skills folders:** these files are installed under `{{AKZO_HOME}}/modules/profiles`, which Copilot does
  not scan. Placing them in a skills or instructions folder that Copilot loads would apply DAB and CDMS rules to every
  agent and every repository.
- **Your own versions:** save a file with the same relative path under `{{AKZO_HOME}}/profiles-custom/` (for example
  `profiles-custom/instructions/cdms/sonar-rules.instructions.md`). The helper then lists your file instead of the shipped
  one, marked `custom`. The installer never writes, replaces, or removes anything in `profiles-custom`.
- **Source material:** these files were written from the Akzo Master SDD 3.6.0 brief. The team's original agent
  instructions, the SonarCloud rule catalogs, and the `add-feature` and `run-tests` skills were not available when they
  were written. Put the originals in `profiles-custom` to use them as written; until then, treat every rule here as a
  baseline to verify against the repository and its SonarCloud quality profile.
