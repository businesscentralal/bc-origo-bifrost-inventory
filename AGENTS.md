# Bifrost Inventory — agent notes

- Namespace: `Origo.Bifrost.Inventory` / `Origo.Bifrost.Inventory.Test`
- Follow OrigoSoftwareSolutions/bc-dev-standards
- Scope: 44 `Inventory.*` message types across eleven domains (attributes, transfer orders,
  assembly, reservations, item tracking, physical inventory, costing, reclassification, item
  application, inventory periods, item price). Costing and price types ship:
  `Inventory.Cost.Get`, `Inventory.AdjustCost.Run`, `Inventory.CostToGL.Post`/`.Test`,
  `Inventory.Revaluation.Calculate` and `Inventory.Price.Update` (the earlier "cost/price out"
  decision from inventory#3 was reversed). README lists every type.
- Permissions: reads and writes extend Foundation's `BIFROST Read ori` / `BIFROST Full ori`
  (`BIFROST InvRead ori`, `BIFROST InvWrite ori`, with the non-assignable attribute sets).
  The one assignable set is `BIFROST InvPost ori` (10076837): the posting gate
  (`Inv. Posting Gate ori` checks write permission on the token table `Inv. Posting ori`) and the
  Inventory Setup page/table. It must stay assignable: nothing else grants posting, and the
  permission-coverage guard needs an assignable set for the setup page. No Foundation `Setup ori`
  tabledata grants.
- Foundation floor 28.0.8.617 (release `28.0.8`, probed by `.AL-Go/settings.json`);
  `application` floor 28.3.0.0. CodeCop, UICop and AppSourceCop run on app and test app with
  `failOn: warning`.
- Context-sensitive help: `contextSensitiveHelpUrl` `https://docs.bifrost.origo.is/{0}/help/inventory/`;
  `Inventory Setup ori` uses slug `inventory-setup`. A new page needs a slug and both locale pages
  in businesscentralal/bifrost.

## AppSource build gate

`tools/Assert-AppSourceBuild.ps1` runs from `.AL-Go/PipelineInitialize.ps1`,
`.AL-Go/CompileAppWithBcCompilerFolder.ps1`, `.AL-Go/PostCompileApp.ps1`,
`.AL-Go/PipelineFinalize.ps1` and the Pipeline stage step in `_BuildALGoProject.yaml`. It was
ported from Bifrost Attachments; see `tools/AppSourceBuildGate.md`. The Signed stage is deferred
(no NAVX trust on hosted runners). Changing the Foundation floor or the BC artifact needs the
pins in `tools/appsource_gate.py`, `tools/stage_foundation_inputs.py` and
`tools/check_build_inputs.py` reviewed together.

## Preserve the Bifrost build pipeline during system updates

Run `tools/Test-BifrostPipeline.ps1` and `tools/Test-SharedAlpacaContainer.ps1` before
opening a pipeline PR; the independent **Bifrost Pipeline Guards** workflow runs both.
AL-Go and Alpaca updates must retain sequential Default/Test builds, filtered container
creation, physical container identity, Test production-app republishing, Default internals
stripping, signing requests, deferred cleanup, merged settings before secrets, and Test-only
upgrade skipping. Keep this repository's app IDs, action versions, dependency settings and
deployment variables. Apply compatible upstream updates and reapply the Bifrost custom blocks
before pushing; do not disable the guard or exclude generated workflows from future updates.
