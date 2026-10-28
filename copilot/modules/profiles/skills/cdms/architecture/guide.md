# CDMS architecture

> Profile skill `cdms-architecture`: CDMS (ColorDMS) layers, XRM service architecture, and boundaries. Load only when the helper's profile is cdms.

Shipped baseline written from the 3.6.0 brief. The team's AN.ColorAppsAzure.ColorDMS agent instructions replace this file
when saved under profiles-custom (see `profiles/README.md`). Applies only when `profile` reports `cdms`.

Azure Functions, Clean Architecture, CQRS through `IDispatcher`, Dynamics CRM through the XRM SDK, `CrmOperationBase`
implementations, EF6 where the solution uses it, Scrutor handler discovery, and CRM service registration in
`ServiceRegistration.CrmServices.cs`. Confirm each of these in the solution before relying on it.

| Part | Owns |
|---|---|
| Formula.Application (verify the project name) | CQRS commands, queries, handlers, business orchestration |
| Data/XRMService interfaces and implementations | CRM access through `CrmOperationBase`-derived services and CRM SDK operations |
| MarketColorDbContext (where the feature uses it) | EF6 data access, as sibling features use it |
| CDMS Functions and response helpers | HTTP triggers, dispatching, response mapping |
| Registration extensions | Scrutor scanning for handlers; CRM service registration |

- Follow the XRM service architecture. Do not generate StrawberryShake GraphQL integrations, and do not import DAB
  service patterns, unless the developer explicitly requires and approves it.
- CRM entities, attributes, relationships, and option-set values are used only after you find them in the code (early-bound
  classes, constants, or existing queries). An option-set value never comes from memory or a document alone.
- Never run DAB solution commands here; `guard -Repo <id>` refuses them.
- **Plugin-owned behavior:** a rule a CRM plugin already enforces (verified in the plugin's code) stays there; do not
  duplicate its validation in the API. Approved rules derived from workflows or JavaScript that the API must enforce are
  implemented through the XRM service architecture. Inspect a plugin only when the affected flow runs through it, and
  report partial plugin coverage or missing branches (business rule branch coverage skill). DAB GraphQL and DAB
  exception-handling conventions do not apply here.
