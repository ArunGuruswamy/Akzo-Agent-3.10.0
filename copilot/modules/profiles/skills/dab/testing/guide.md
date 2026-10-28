# DAB testing

> Profile skill `dab-testing`: DAB build and test commands and test conventions. Load only when the helper's profile is dab.

Shipped baseline from the 3.6.0 brief; the Formula agent instructions in profiles-custom replace it (see
`profiles/README.md`). Applies only when `profile` reports `dab`.

## Commands (from the brief; verify the solution and runsettings locations first)

```
dotnet build AN.ColorAppsAzure.BL.sln
dotnet test AN.ColorAppsAzure.BL.sln --settings coverlet.runsettings --collect:"XPlat Code Coverage"
```

- `profile -Repo <id>` returns these commands with the solution's real folder and whether `coverlet.runsettings` exists
  there. Run them from that folder. Add `--results-directory "<evidence>"` so coverage is written under the task's
  evidence folder, never into the repository.
- Never run the CDMS solution or CDMS test commands here; `guard -Repo <id>` refuses them.

## Conventions

- Use the test framework, mocking library, and assertion style of the existing DAB test projects (read them; do not
  assume the CDMS stack).
- Focused tests while implementing (`--filter` on the new test class), the full solution before handover.
- Cover the successful path, invalid input (the validator and the HTTP response it produces), and dependency failure (the
  GraphQL service returning errors).
- Record failures that also fail at baseline separately from failures the change introduced.
- Changed-line coverage: `coverage -Repo <id> -Report "<cobertura report>"`.
