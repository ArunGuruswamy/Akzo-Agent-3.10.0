# DAB architecture

> Profile skill `dab-architecture`: DAB (AN.ColorAppsAzure.BL) layer boundaries and execution path. Load only when the helper's profile is dab.

Shipped baseline written from the 3.6.0 brief. The team's AN.ColorAppsAzure.Formula agent instructions are the primary
DAB reference and replace this file when saved under profiles-custom (see `profiles/README.md`). Applies only when
`profile` reports `dab`.

Azure Functions (isolated worker), Clean Architecture, CQRS through `IDispatcher`, FluentValidation, application
handlers, and StrawberryShake GraphQL clients for the Formula, MarketColor, and ComplexUpdate schemas. Confirm each of
these in the solution before relying on it.

| Layer | Owns | Never |
|---|---|---|
| Function | HTTP triggers, authorization level, OpenAPI attributes, dispatching, middleware, response mapping | business rules, GraphQL calls, validation the application layer already performs |
| Application | CQRS commands, queries, handlers, validators, business orchestration, response models | HTTP types; generated GraphQL types in public contracts |
| Data | StrawberryShake GraphQL implementations behind service interfaces | business decisions, HTTP concerns |
| Common | shared constants, helpers, utilities | feature logic |

- Dependencies point inward: Function -> Application -> service interfaces; Data implements those interfaces.
- **There is no separate DAB plugin.** Every approved business rule is implemented in DAB code, in the layer that owns
  it (validator, handler, application service, GraphQL data service), including rules the PBI derives from CRM plugins,
  workflows, custom workflow activities, JavaScript validations, HTML web resources, or another backend. Read that
  legacy source only for the rules the PBI names (business rule branch coverage skill, section 4); routine DAB work does
  not analyse plugins. Never add a CRM runtime dependency, never change the legacy code, and do not port UI-only
  behavior. Check what DAB already covers before adding anything.
- Never apply CDMS rules here: no XRM services, no `CrmOperationBase`, no Scrutor scanning assumptions.

## Execution path to trace for every change

Function -> Dispatcher -> Application handler -> validation -> `AppValidationException` (verify the type name) ->
exception middleware -> HTTP response. Read each hop in the code and note which component produces the status code, the
field name, and the message the client receives.

## Before adding a file

Find the nearest sibling feature (same schema, same kind of operation) and mirror its folders, names, and registrations.
A new layer, framework, or pattern the siblings do not use is an architecture change and needs the developer's approval.
