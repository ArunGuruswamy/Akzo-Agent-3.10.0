# CDMS run tests

> Profile skill `cdms-run-tests`: CDMS build and test commands and test conventions (MSTest, NSubstitute). Load only when the helper's profile is cdms.

Shipped baseline from the 3.6.0 brief; the team's `run-tests` skill replaces it when saved under profiles-custom (see
`profiles/README.md`). Applies only when `profile` reports `cdms`.

## Commands (from the brief; verify the solution location first)

```
dotnet build AN.ColorAppsAzure.BL.ColorDMS.sln
dotnet test AN.ColorAppsAzure.BL.ColorDMS.sln --collect:"XPlat Code Coverage" --results-directory ./TestResults
```

- `profile -Repo <id>` returns these commands with the solution's real folder. The agent writes test results and coverage
  under the task's evidence folder (`--results-directory "<evidence>"` in place of `./TestResults`) so nothing is added to
  the repository; use `./TestResults` only when the developer asks for it, and never commit it.
- Never run the DAB solution here; `guard -Repo <id>` refuses it.

## Conventions

- MSTest and NSubstitute, in the existing test projects and folder layout.
- Cover: the successful operation, invalid input, dependency failure (the XRM service or organization service throwing or
  returning nothing), and each meaningful branch.
- Focused tests while implementing (`--filter "FullyQualifiedName~<TestClass>"`), the full solution before handover.
- Record failures that also fail at baseline separately from failures the change introduced. Never claim a run you did
  not see finish.
