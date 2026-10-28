# Agent evaluations (3.7.0)

Akzo SDD Agent — Developed and maintained by Arun RG

Reusable evaluation cases for development and PR review in any repository profile. Fixtures are synthetic (generic
orders/refunds/colors features); none of them names a real PBI, branch, or class, and none is read by the agent or the
helper at run time, so they cannot become routing rules.

Two kinds of evidence:

- **Automated**: a check in `scripts\test.ps1` that runs the helper on a generated fixture repository. Result: the suite
  run recorded in `evaluation-report.html`.
- **Live**: needs the agent in Copilot Chat on a real or representative repository. Run the prompt, compare with the
  expected behavior, and record PASS / FAIL in `benchmark\results-template.csv`. Until then the case is **NOT VERIFIED**.

| # | Case | Fixture / prompt | Expected behavior | Evidence |
|---|---|---|---|---|
| 1 | Existing validator reuse | Feature with `CreateOrderValidator`; PBI adds a required-field rule | Extends the existing validator; no new validator class; test per rule | Live. Guidance: source-grounded skill "Validation ownership", DAB FluentValidation step 5 |
| 2 | Collaborator validation consolidation | Same rule in a validator and a `...Collaborator` | Reports the duplicate, proposes one owner by what the rule needs, keeps messages and order | Live |
| 3 | Unnecessary abstraction detection | New `OrderRuleHelper` used by nothing else | `review` warns `single-use-abstraction`; agent removes or justifies it | Automated: "review: a new helper type ... single-use-abstraction" |
| 4 | Naming convention enforcement | New file named off the sibling pattern | Renamed to the conventions table from the sibling (`path:line`) | Live (conventions table, section 2) |
| 5 | Dependency cleanup | Remove an interface reached by assembly scanning | Finds references, registration, tests, scanning before removing | Live. Guidance: "Abstractions: add or remove" |
| 6 | Reviewer comment resolution | Three PR comments, one wrong | Each comment verified against code; two fixed, one answered with evidence; every comment has a disposition; same issue fixed elsewhere in the feature | Live. Guidance: pre-PR review sections 3 and 5 |
| 7 | Duplicate validation detection | Same block added twice in a change | `review` error `duplicate-change` | Automated: 3.6.0 scenario 3 checks |
| 8 | Incomplete Yes/No branches | Rule "approved -> process, not approved -> reject"; only Yes implemented | Branch table shows No as MISSING; classified EXTEND; smallest change + test for No | Live. Guidance: business rule branch coverage skill |
| 9 | Error contract preservation | Function converts the validation exception the middleware already handles | `review` error `redundant-validation-conversion`; removed only if middleware keeps field, message, status | Automated: 3.6.0 scenarios 1-2 |
| 10 | Cross-feature regression impact | Change in a shared Application project | `affected` selects the dependent test projects and not unrelated ones | Automated: "affected: ... unrelated Reports.Tests excluded" |
| 11 | GraphQL query reuse | Needed data already selected by an existing operation | Reuses or extends the operation; no duplicate document | Live (section 2, contracts before adding anything) |
| 12 | DI registration errors | New handler not registered | Integration check finds it; registration added where siblings register | Live (section 6 integration check) |
| 13 | SonarCloud compliance | Changed method over cognitive complexity 15 | Fixed with the smallest change; remote gate not claimed without a server result | Live; helper Sonar queries automated in the Sonar checks |
| 14 | Analysis before approval | "Review this and propose a fix before changing anything" | Analysis, file-by-file proposal, risks, test plan; no file edited | Live. Agent: "Review-only / plan-first" |
| 15 | Fast source investigation | Exact class name in the request | `context` exact hit with tests and callers; no repository scan | Automated: "context: an exact type name returns that file with its tests and direct callers" |
| 16 | Profile separation | Request in a CDMS repository | Only CDMS and shared files loaded; DAB files in `neverLoad`; DAB solution commands refused | Automated: isolation, lazy loading (CDMS), and guard checks |
