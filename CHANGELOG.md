# Changelog

## [Unreleased]

### Fixed - Icelandic release wording (#244)

- Correct the Icelandic code captions and valuation help, clarify the mutually exclusive AdjustCost filters, and restore the CostToGL `UnknownParameter` outcome and AssemblyOrder `PreviewPost` recommendation. Keep the authoritative AL translation comments and generated is-IS XLF synchronized. No object IDs added; English source strings and message contracts are unchanged.
### Fixed (2026-11-18) - typed-refusal item fixture reruns on a reused company (#248)
- `Scenario_AC01_ItemNoReadRefusals_EN/_IS` in test codeunit 96975 `Inv. Typed Refusal Tests ori` no longer rename a library item onto the numeric key. They insert the owned item under a key that is free in `Item` and `Item Unit of Measure`, so leftover unit-of-measure rows from an earlier run cannot collide. They also delete the item (and its dependent rows) at the end. All assertions remain. New regressions `NumericItemNo_SkipsLeftoverUnitOfMeasure_EN/_IS` seed a leftover unit-of-measure row on a fixed random sequence and prove the key is skipped. No new object.
### Added (2026-11-18) - domain gate regression for every Inventory type (#36)
- Test codeunit 96970 `Inv. Contract Parity Tests ori` gains `Scenario_Issue36_EveryTypeWithDomainsOff_RefusesBeforeWork`: with every Inventory Setup switch off, each type stays registered, reports `IsEnabled` false and refuses with `InvalidParameter`/`PreconditionFailed` naming its domain (or stops at the licence check first), and no item or item ledger entry changes. Eleven later types that belong to none of the #36 domains (item units of measure and variants, posted shipment/receipt line copy and undo, return order from posted, requisition worksheet) are pinned by name so a new ungated type fails the test.
- `Scenario_Issue36_SetupIsPerCompanyBooleanSwitches` pins Inventory Setup as company-scoped with only Boolean domain switches.
- Test-only change: no new app object, page or message type.

### Changed (2026-11-18) - irreversible Inventory types name what expectedCount counts (#192, core#1365)
- `Inventory.Revaluation.Post`, `.AssemblyOrder.Post`, `.AdjustCost.Run` and `.CostToGL.Post` keep their `irreversible` effect and now state the count unit in `effect.changes` and on the `expectedCount` parameter, in en-US and is-IS (the other five listed types, including `.TransferOrder.Post`, already did on main). The count is always 1: the one order, batch or run, not lines or entries. Read it without a side effect by sending the request without `expectedCount` and reading `expected`.
- New test codeunit 96935 `Inv. Count Unit Tests ori` (1033 and 1039). No new app object, page or message type.

### Fixed - confirmation posting fixture on reused tenants (PR #202)

- Reserve native value-entry numbers above existing posting-queue keys without deleting or replacing tenant data, and clear stale sequence buffers before the confirmation posting fixture runs.
- Add bilingual regressions with an occupied queue key above the ledger. All native success, confirmation-boundary and exact revaluation-amount assertions remain; the regressions also verify the existing queue row is preserved.
- Reconcile both exact catalogue counts and README with main's merged catalog-item registration: 97 total types, 87 Inventory types. Preserve the complete explicit roster and both membership checks.

### Fixed (2026-11-17) - Reused test-company fixtures (PR #207 amend)

- Transfer posting, confirmation and cycle-count fixtures advance the Microsoft test-library number sequence beyond existing padded G/L accounts, preserving existing accounts and all behavior assertions.
- Planning fixtures use unique XP117 item numbers. Cleanup selects those owned numbers instead of descriptions, so unrelated BOM components with an older fixture description or a foreign BOM parent survive; a regression test covers that boundary.

### Fixed - repeatable owned-tenant fixtures (PR #201)

- Transfer fixtures retain native warehouse location creation with main’s collision-safe library sequence preparation and fresh GUID-based posting accounts. Confirmation journal fixtures use the same helper, and ATP service-item refusals use independent item keys. Existing accounts are preserved. The collision regression initializes native item-posting prerequisites before occupying the generated number, including on a fresh CI company.
- Availability's non-inventory refusal uses a fresh service item instead of the shared item-number sequence, avoiding leftover BOM references. Regression cases preserve an occupied generated account and an existing BOM component; all original assertions and test isolation remain.

### Fixed - catalog test ID collision (PR #201)

- Move `Nonstock Item Create Tests` from codeunit 96998 to unused codeunit 96934 within the existing test range. Main keeps `Posted Line Undo Tests ori` at 96998. Both test suites, their assertions and product behavior are unchanged.
- Reconcile both exact Inventory registry counts to 83 after merging main's `Inventory.ItemReference.Set`; retain the explicit roster and both membership checks.
- Reconcile both exact Inventory registry counts to 84 after merging main's `Inventory.AvailabilityByEvent.Get` (#200); the explicit roster already lists it and both membership checks stay.
- Reconcile both exact Inventory registry counts to 85 after merging main's `Inventory.AgedInventory.Get` (#195); the explicit roster lists all 85 registered `Inventory.*` types and both membership checks stay.

### Changed - CI probes Foundation 28.0.13

- `.AL-Go/settings.json` probes the published Foundation release `28.0.13` (package 28.0.13.741, source `4458b14`, build 44188373403) instead of `28.0.8`. The AppSource gate candidate (`tools/appsource_gate.py`) and the default collision-restore/staging profile `release741` (`tools/stage_foundation_inputs.py`) pin its exact Apps/TestApps release assets, archive and package hashes, source, build and compiler. `release617` stays an explicit historical profile. The app and test Foundation floors stay 28.0.8.617. No AL objects change.
### Fixed - item tracing review (#107, PR #202)

- Reject `?` in lot, serial, item and variant identifiers before native tracing can match a different identifier. Both locales name the refused wildcard in recovery guidance.
- Permission and caught native-tracing refusals now include localized `nextStep` guidance. Preserve native coded errors and telemetry. Add bilingual wildcard, restricted-permission and native-error regressions.
- Merge current main while preserving both planning types and ItemTracing (78 Inventory registrations). Main keeps purchase receipt process codeunit 10077031; unreleased ItemTracing implementation/message value move to 10076994. Its tests move to 96949 to avoid open #201's claim on 96998.

### Fixed - aged inventory amendment after main merges (#195)

- Reconcile both exact Inventory census assertions to 84 after merging `Inventory.ItemReference.Set` and `Inventory.AvailabilityByEvent.Get` alongside `Inventory.AgedInventory.Get`; the scoped help catalogue contains 50 types. Preserve both read permission grants when merging main. Preserve the explicit roster and every membership assertion. Document safe affected-suite reruns on reused local tenants without deleting existing fixture data.

### Fixed - reclassification test ID collision (PR #221)

- PR #221 build repair: move `Reclass Journal Tests ori` from codeunit 96964 to unused test codeunit 96925; main keeps blank-line tests at 96964. No tests, assertions or product behavior changed.
### Fixed (2026-11-17) - AppSource gate keeps Finalize's baseline reuse for the Pipeline step (#237)

- AppSource build gate (`tools/Assert-AppSourceBuild.ps1`, `tools/appsource_gate.py`, `tools/AppSourceBuildGate.md`): Finalize stores the baseline-reused product it accepted (baseline run, baseline SHA, package file and SHA-256) as `productReuse` in `state.json`. The Pipeline step validates against that record instead of the baseline env and Apps folder, which are gone by then, so test-only PRs no longer fail there. No receipt and no record, a record mismatch, a changed package hash and `app/` changes still fail closed. New tests in `tools/tests/test_appsource_gate.py`; no AL or workflow change.

### Fixed — issue 134 ID clash with merged Get Shipment Lines (#215)

- Move `Sales Undo Impl ori` and `Sales.Shipment.Undo` from 10077028 to 10077016, and `Purchase Undo Impl ori` and `Purchase.Receipt.Undo` from 10077029 to 10077017. Main (#203) now uses 10077028–10077029 for `Sales.SalesInvoice.GetShipmentLines`. Message names and behavior are unchanged. Each message value still matches its implementation codeunit.
- Move the shared helper `Posted Line Undo ori` from 10077027 to 10077014. Open pull request #206 claims codeunit and message value 10077027 for `Inventory.Valuation.Get`. 10077014, 10077016 and 10077017 are free on main and are not claimed by an open pull request. The enum extension stays 10077025.
### Fixed (2026-11-17) - item-reference merge reconciliation (#199)

- Preserve all main message types and permissions alongside ItemReference.Set; the exact Inventory catalogue census is 82. Move this PR's new codeunits to 10076954–10076956 and Set enum value to 10076954; regenerate translations from the merged source. The README roster and local help list Set and its save/read-back workflow.
- Reuse main's transfer compatibility helper 10077025. Posting and preview use the existing BC 29 order's mode even if Inventory Setup changes; BC 28 continues to use setup. Test fixtures restore the exact native posting value, including BC 29's blank value.
- Align English/Icelandic transfer posting notes with the order-based BC 29 behavior and BC 28 setup fallback. Move the unreleased Item Reference Set test codeunit from 96989 to 96928 to avoid PR #206's valuation tests and the earlier PR #236's carry-out help test allocation (96948).

### Added (2026-11-16) - Item reference writes (#102)

- `Inventory.ItemReference.Set` creates or updates references using item, variant, unit, type, type number and reference number. Description and ISO validity dates can be changed; omitted optional values are preserved. Conflicting references on another item return `ConflictingIdentifiers` with recovery guidance. Generic writes to table 5777 are blocked and name the dedicated type.
- Added codeunits 10076954 `Item Ref. Set Impl ori`, 10076955 `Item Ref. Set Proc ori`, 10076956 `Item Ref. Restrict ori`, and tests 96928 `Item Ref. Set Tests ori`. English/Icelandic help and error labels are included; the effect is `write`.
- Extended main's compatibility helper 10077025 `Transfer Posting Setup ori`: transfer posting and preview read the posting mode on the BC 29 order, with the BC 28 setup option as a fallback. Native test setup maps BC 29 enum values 10/20 to the existing shipment/direct choices. Existing transfer tests configure and restore the matching native field, removing BC 29 obsolete-field warnings without raising the supported BC version.
### Added (2026-11-17) - setup mode for Inventory Setup (#235)

- While Foundation setup mode is active for the running message, `Inventory Setup Restrict ori` (10076923) no longer restricts `Inventory Setup ori` (10076836), the only setup/configuration table this app restricts. It reads the public read-only facade `Bifrost Setup Mode ori` (`IsActive`). Every other restricted table (Item cost/price fields, Item Category, Item Attribute tables, Item Variant, Stockkeeping Unit, Price List Header/Line, Reservation Entry, Tracking Specification, Item Charge Assignment) is business data routed through validated message types and stays restricted. Foundation already logs each successful Data.Records.Set write made in setup mode, so this subscriber (which only decides restriction and also runs for probes that write nothing) does not call `LogWrite` a second time.
- The Inventory Setup page shows a Setup mode help text (en-US, is-IS, XLF regenerated) naming the one table setup mode opens. New test codeunit 96929 `Inv Setup Mode Tests` (moved from 96997 on the PR #238 main merge; main retains `Posted Undo MCP Fixture ori` at 96997). No new objects besides the test codeunit. Foundation dependency floor raised in app and test manifests to 28.0.13.0 (the line containing the facade, core#1408/#1410).

### Fixed
- PR #201 main merge: preserve both Catalog Items and Available to Promise in the explicit registry; assert all 86 Inventory types and 51 scoped contracts after merging #211.
- #234: `Purchase.Requisition.CarryOut` (10076942) and `Inventory.PlanningWorksheet.CarryOut` (10076939) state what `expectedCount` counts. effect.changes and the expectedCount parameter say `expectedCount counts worksheet selections: always 1` (Icelandic: `expectedCount telur val á vinnublaði: alltaf 1`), not the number of lines or orders. Requisition carry-out now declares the expectedCount parameter itself so Foundation keeps that sentence. New test codeunit 96948 `CarryOut Count Help ori` (96964 is `Inv. 186 Blank Line Tests ori` on main). No new product object IDs.
### Changed (2026-11-17) - Catalog Items and Planning allocation (#119)

- Main-merge 2026-11-17: Planning keeps domain value 17, setup field 27 and wizard slot 18. Catalog Items uses the next free domain value 18, setup field 28 and wizard slot 19; both tagged migrations remain independent.

### Changed (2026-11-17) - Catalog Items IDs after purchase returns landed (#119)

- Main keeps Purchase Returns as domain value 16, Inventory Setup field 26 and setup-guide slot 17. Catalog Items moves to domain value 17, setup field 27 and setup-guide slot 18. `Inventory.NonstockItem.Create`, codeunits 10077019 and 10077021, and the upgrade tag `Origo.Bifrost.Inventory-CatalogItemsUsage-20261116` are unchanged. Domain-usage assertions for Catalog Items use field 27, and the setup loops include that field.
### Fixed - catalogue census after main merges (PR #211)

- Paired CI at `da644d87` failed `AllInventoryTypes_RelatedNamesExist`: the test still expected 78 Inventory types after main's cycle count landed. Merging main again brought `Inventory.ItemVariant.Get` and `Inventory.ItemVariant.Create`, whose roster expects 80 without available-to-promise. This branch also registers `Inventory.AvailableToPromise.Get`, so the explicit roster and the enum extensions name 81 Inventory types at `e3c6975`. Merging main `84f3c288` (#206) keeps `Inventory.Valuation.Get` as well. The registry now names 84 Inventory types (83 after main's `Inventory.ItemReference.Set` (#199), and 84 with `Inventory.AvailabilityByEvent.Get`), so codeunit 96921 expects 84. The README overview counts every message type, 94, the same split #206 used (Inventory census versus overview). No message contract changed.

### Fixed - blank-line test ID collision (PR #211)

- Main owns codeunit 96964 as `Inv. 186 Blank Line Tests ori`. Move unreleased `Avail. To Promise Tests` from 96964 to 96926, the first free codeunit ID in the test range after checking main and every open Inventory pull request (96925 is claimed by #221). `Avail. To Promise Perm` stays 96924. Test behavior is unchanged.

### Fixed - main merge reconciliation (PR #211)

- Preserve main's Planning test codeunit 96965. Move the unreleased `Avail. To Promise Perm` test codeunit from 96965 to 96924, the first free codeunit ID in the test range after checking main and open PRs. Test behavior is unchanged. That merge retained 78 Inventory types; later main merges raise the census, and the catalogue bullet above states the current count.

### Fixed — available-to-promise requested date (#105, PR #211)

- A purchase receipt before the requested date now promises the requested date instead of returning the earlier receipt date and incorrectly refusing the request. Normalize nonempty ATP dates before comparing with capable-to-promise; cover earlier and same-day receipts, including CTP enabled, with regression tests.

### Added (2026-11-16) - Inventory.AvailableToPromise.Get answers when a quantity can be promised (#105)
- New message type `Inventory.AvailableToPromise.Get` (enum value 10077000 in enum extension 10077000 `MsgType.AvailToPromise.Ext ori`; codeunit 10077000 `Avail. To Promise Impl ori`). It takes `itemNo`, `quantity` and `requestedDate` plus the optional `variant`, `location` and `capableToPromise`, and answers `availableOnRequestedDate`, `canPromiseOnRequestedDate`, `earliestDate` and `basis`, as the Order Promising page does (codeunit 5790 `Available to Promise` with the Check-Avail. fields on Company Information).
- Capable to promise (codeunit 99000886) runs only with `capableToPromise: true` (off by default). It uses a private order promising id, so no number series is used, and the requisition lines it builds are deleted before the answer. No order promising lines or reservations are kept.
- Refusals: `MissingParameter`, `InvalidParameterFormat`, `UnknownParameter`, `RecordNotFound` (item, variant, location), `InvalidParameter` (quantity 0 or below, Availability domain off), `PreconditionFailed` (service or non-inventory item; capable to promise without an order promising template and worksheet), `PermissionDenied`. Each carries a `nextStep`; help and refusals are in en-US and is-IS (XLF regenerated).
- The contract declares its real effect: `read`, nothing kept, idempotent (core#1365 D1). Gated by the existing Availability domain; no new setup field. `BIFROST InvRead ori` and `BIFROST InvWrite ori` execute the codeunit.
- Tests: `Avail. To Promise Tests` (96926) and `Avail. To Promise Perm` (96924). `Inventory Contract Batch Tests` counts 84 Inventory types and 50 scoped types after the cycle-count and item-variant merges. The earlier 96964/96965 test IDs and the 60/72/78 census figures were superseded by the ID reconciliations in this unreleased section.

### Fixed - main merge ID reconciliation (PR #233)

- Preserve main's Standard Cost implementation and message value 10076938. Move the unreleased Planning Calculate codeunit and matching message value to the next unclaimed ID 10076949 (10076939-10076948 are allocated on main or open PRs). Both Planning operations and Standard Cost retain their behavior. The combined registration census retains all 77 Inventory types, including main's two Item Unit of Measure types.

### Fixed - planning worksheet review (#233)

- Preserve Item Substitution domain 15/field 25; move unreleased Planning to domain 17/field 27 and independent wizard slot 18, preserving Purchase Returns 16/26 from main #219. Reconcile the 65-type catalogue and Foundation-composed contracts. Confirmation boundary tests name a subject; planning regression tests verify other worksheets survive calculation. Add explicit owned MCP seed/cleanup actions to the test app. Collect committed native transfer and assembly headers when the resilient report does not share its nested document buffer; new regression cases verify both order types.

### Added
- #117: `Inventory.PlanningWorksheet.Calculate` (10076949) replaces suggestion lines for the selected items on one planning worksheet and returns those lines. `Inventory.PlanningWorksheet.CarryOut` (10076939) creates new purchase, transfer and assembly orders from accepted New lines. Lines that would cancel, change the quantity of, reschedule, or otherwise change an existing document, and production-order lines, are refused before any write. Carry-out is irreversible: `expectedCount` counts one invocation of the selected worksheet, not the number of orders or lines. Calculate commits as it proceeds and limits the native item-line delete to that worksheet. New objects: enum extension 10076947, codeunits 10076949, 10076939 and 10076946, enum value 17 Planning, setup field 27 Planning, test codeunit 96965 (96968 was taken by SKU Tests on main, so this PR moved to the next unused test ID). The one-time upgrade tag `Origo.Bifrost.Inventory-PlanningDomain-20261117` turns on Planning only.
### Fixed — issue 134 merge with main

- Move the PR’s `Posted Line Undo Tests ori` test codeunit from 96996 to the next free ID 96998: main uses 96996 for `Purch Get Receipt Tests`. Test behavior and the fixture objects at 96997 are unchanged.

- Move the PR’s Sales/Purchase undo implementation codeunits and message values from 10077025–10077026 to the next free IDs 10077028–10077029: main uses 10077025 for Transfer Posting Setup and 10077026 for Transfer Ship. The shared helper stays 10077027 and the enum extension stays 10077025. Both features retain their behavior.

### Added ([28.3.2.0] development) — issue 134

- Add `Sales.Shipment.Undo` and `Purchase.Receipt.Undo` with explicit posted document / unique line selection, native sales and purchase reversal routines, corrective entries and atomic selection checks. Invoiced, corrected and applied-entry restrictions return coded refusals with recovery guidance.
- Declare irreversible posting, standalone commit semantics and one-document `expectedCount` in English and Icelandic help.
- App objects: codeunits / enum values 10077016–10077017, shared codeunit 10077014, enum extension 10077025. Test objects: codeunit 96998; explicit owned fixture codeunit / page 96997.

### Added (2026-11-16) - purchase invoice receipt lines (app [28.3.2.0], #133)

- `Purchase.PurchaseInvoice.GetReceiptLines` adds posted, not invoiced receipt lines to an open purchase invoice through native codeunit 74 `Purch.-Get Receipt`. Select `receiptNos` or `allReceipts`; identify the invoice by `documentNo` or `systemId`. The response lists added invoice lines, receipt linkage and skipped invoiced/already-selected lines. Another pay-to vendor or currency is refused atomically with `InvalidLine` and `nextStep`.
- Declares `effect: write`, `posts: false`; en-US/is-IS discovery, help and XLF entries are included. New objects: codeunit 10077018 `Purch Get Receipt Impl ori`, codeunit 10077031 `Purch Get Receipt Proc ori`, enum extension 10077030 `MsgType.PurchGetRcpt.Ext ori`, message value 10077018, test codeunit 96996 `Purch Get Receipt Tests`. Foundation document APIs remain unchanged.
- Main-merge (2026-11-17): codeunit 10077030 is `Reserv. Supply Filter ori` on main. The receipt implementation and its message value moved from 10077030 to 10077018, the next ID free on main and not claimed by an open pull request (10077027 is claimed by #206 and #215; 10077028–10077029 by #203). Enum extension 10077030 and process codeunit 10077031 stay. The message name is unchanged.
### Fixed (2026-11-17) - Catalogue census after main merges (PR #203)

- Reconciled codeunit 96921's expected census with the merged registrations: 48 scoped localization entries and 71 Inventory message types, including Item.Create from main. The explicit rosters, bidirectional membership checks and English/Icelandic assertions remain intact.

### Added (2026-11-16) - Sales.SalesInvoice.GetShipmentLines (#132)

- New message type `Sales.SalesInvoice.GetShipmentLines` (enum value 10077028 in enum extension 10076900 `MsgType.SalesGetShpt.Ext ori`; codeunits 10077028 `Sales Get Shipment Impl ori` and 10077029 `Sales Get Shipment Proc ori`; renumbered from 10077020-10077021 when merging main, because #118 took codeunit and enum value 10077020 and open PRs claim 10077021-10077027). It pulls posted, not invoiced sales shipment lines into an open sales invoice through native codeunit 64 `Sales-Get Shipment` (`SetSalesHeader`, `CreateInvLines`), the same routine as the Get Shipment Lines action, so remaining-quantity checks, item charge copying and the invoice-to-shipment link stay native.
- Request: `documentNo` or `systemId` of the open invoice, and `shipmentNos` (array) or `allShipments` (true). A shipment of another bill-to customer or currency is refused with `InvalidLine` and nothing is added; already invoiced lines, and lines already on an open sales invoice, are skipped and listed in `skippedLines` (`invoiced` / `onOpenInvoice`), so sending the same request again adds nothing. Released invoices answer `PreconditionFailed` pointing to `Sales.Document.Reopen`. Every refusal has a Bifröst code and `nextStep`.
- Effect `write` (not irreversible; nothing is posted and added lines can be deleted), `posts: false`, `idempotent: true` (core#1365 D1). Help, refusals and examples in en-US and is-IS; is-IS.xlf regenerated with `tools/Update-IcelandicXlf.ps1`.
- Invoice line types and status values use English enum names in both locales, matching the shared response convention.
- Blank and longer-than-20-character invoice/shipment numbers are rejected with `InvalidParameterFormat` before lookup, so a long identifier cannot silently select a different document by its prefix.
- `BIFROST InvWrite ori` grants X on the two new codeunits. Tests: new codeunit 96995 `Sales Get Shipment Tests` (happy path for named and all shipments, other bill-to customer, invoiced and already-pulled edge cases, released invoice, coded invalid input, bilingual help).
### Added (2026-11-16) - Inventory.ItemTracing.Get (#107)
- `Inventory.ItemTracing.Get` traces a lot or serial number through the item ledger as the Item Tracing page does (Item Tracing Mgt., codeunit 6520). Send `lotNo` and/or `serialNo`, optionally `itemNo` and `variantCode`, and `direction` (`originToUsage`, the default, or `usageToOrigin`). The answer is the trace tree as a flat `nodes` list in tree order with `level`, `entryNo`, `parentEntryNo`, `entryType`, `documentNo`, `postingDate`, `itemNo`, `variantCode`, `lotNo`, `serialNo`, `locationCode`, `quantity`, `remainingQuantity` and `open`. Neither lot nor serial answers `MissingParameter`; filter characters, a bad `direction` or a too long value answer `InvalidParameter`; an unknown number answers `RecordNotFound`; a trace above 1000 nodes answers `LimitExceeded`. Effect: read. It uses the Item Tracking domain.
- Objects added: codeunit 10076994 `Item Tracing Get Impl ori` (message type value 10077031), enum extension 10077029 `MsgType.ItemTrace.Ext ori`; the codeunit is added to `BIFROST InvRead ori` and `BIFROST InvWrite ori`. Test app: codeunit 96998 `Item Tracing Get Tests`; `Inventory Contract Batch Tests` (96921) now expects 72 types registered by this app. is-IS help and captions are in the Icelandic XLF.

### Added (2026-11-16) - Inventory.AgedInventory.Get (#110)
- New read-only message type `Inventory.AgedInventory.Get` (codeunit 10076948 `Aged Inventory Get Impl ori`, enum extension 10076851 `MsgType.AgedInv.EnumExt ori`, enum value 10076948). It mirrors the Item Age Composition - Qty. and - Value reports: remaining quantity and value of open positive item ledger entries in five age buckets counted back from `endingDate` (default work date) in steps of `periodLengthDays` (default 30), per item. Items are selected with `itemNo`/subject, a SystemId key or `tableView` (none = every item) and filtered with `locationFilter`, `variantCode` and `itemCategoryFilter`. Paged with `skip` and `take` (`noOfLines`, `totalNoOfLines`). Declares `effect: read`; Costing domain; granted through `BIFROST InvRead ori`.
- Refusals carry a Bifröst error code with `nextStep` (`InvalidParameterFormat`, `InvalidParameter`, `RecordNotFound`, `PermissionDenied`, `ConflictingIdentifiers`). Help in en-US and is-IS, `Bifrost Inventory.is-IS.xlf` regenerated.
- Tests: codeunit 96981 `Aged Inventory Get Tests` (buckets and value, paging, edge: entries after the ending date, invalid input). After the merge with main, the 96921 census is 49 scoped types and 74 registered Inventory types (the previous 72 plus `Inventory.StandardCost.Suggest` and `Inventory.StandardCost.Implement`).
- Main-merge ID collision: Aged Inventory keeps its message name and behaviour and takes codeunit and enum value 10076948 (formerly 10076930) and enum extension 10076851 (formerly 10076847). Purchase Return keeps codeunit and enum value 10076930 and enum extension 10076847. 10076948 was free on main and on the open inventory pull requests checked with this merge. The read permission grant stays on `BIFROST InvRead ori`.

### Added (2026-11-16) - Inventory.CycleCount.Calculate (#120)
- New message type `Inventory.CycleCount.Calculate` (enum value and codeunit 10076970 `Cycle Count Calc Impl ori`, enum extension 10076870 `MsgType.CycleCount.EnumExt ori`; logic in `Inventory Native Journal ori` 10076840 and operation `CycleCount` of `Inventory Write Process ori`). It fills one empty Phys. Inventory batch with the items (and stockkeeping units with their own counting period) whose Next Counting Start Date is on or before `postingDate`, using native report 790, then advances their counting dates with the native `Phys. Invt. Count.-Management`, so a repeat call does not select them again. Effect `write`; nothing is posted (posting stays with `Inventory.PhysInventory.Post`).
- Refusals carry a code, `expected` and `nextStep` in en-US and is-IS: `PreconditionFailed` for an `itemNo` item without a counting period or for a batch that already has lines, `RecordNotFound` for an `itemNo` filter that matches no item, `MissingParameter`/`InvalidParameterFormat` for `postingDate` and `documentNo`, `InvalidParameter` or `UnknownParameter` for undeclared keys. Help (description, keywords, selection, overview) in en-US and is-IS; XLF entries added.
- Report 790 runs in native cycle mode (`InitializePhysInvtCount`): lines carry `Phys Invt Counting Period Code`/`Type` into the physical inventory ledger; an item period skips only SKU-backed stock combinations, and an SKU period calculates exactly the SKU's location and variant (blank values included).
- Tests: codeunit 96985 `Inv. Cycle Count Calc Tests` (happy path, repeat call, not yet due, no counting period 1033/1039, missing postingDate, unknown key, blank-variant SKU, due item with a not yet due SKU, SKU combination skipped). No public procedure or field changed.

### Added (2026-11-16) - Item availability event timeline (#104)

- `Inventory.AvailabilityByEvent.Get` returns dated supply and demand, source documents, signed base quantities and the standard running projected inventory. Exact item/variant/location selectors and inclusive dates use the Item Availability by Event calculation; earlier events contribute to opening inventory. No business records are changed.
- Adds codeunit **10076940** `Avail. By Event Impl ori`, enum value **10076940** in extension 10076835, read/full execute permissions, Icelandic help and recovery labels, and regression test codeunit **96990** `Avail. By Event Tests ori`.
- BC 29 build prerequisite: transfer Post/PreviewPost use the native per-order direct-transfer mode through shared codeunit 10076906, with the BC 28 Inventory Setup fallback retained. The test helper selects the active setup schema; two regressions in codeunit 96914 check both modes. No warning suppression or public contract change.

### Fixed (2026-11-17) - Confirmation test targets (PR #213)

- Test codeunit 96978 names an explicit target for confirmation-boundary dispatches and passes the owned item or journal batch to native-success checks. This preserves missing-count, wrong-count and no-write assertions with Foundation's unnamed-request validation behavior (#1278); product contracts are unchanged.
- Test-only fixture codeunit 96973 refreshes the owned item and marks its removed ledger data as adjusted before native deletion, so explicit fixture cleanup does not rerun cost adjustment on deleted test entries. It removes the fixture locations' posting setup, linked customer contacts and empty item registers, making seed/cleanup repeatable. Unposted owned transfers are reopened through the native codeunit before deletion. A native direct-transfer seed lets the touched posting/preview paths be verified independently of the unchanged Create type.
- Fixture cleanup removes posted transfer lines one document at a time, retaining each header number until deletion. A repeat cleanup also removes empty posted headers scoped to the fixture's exact source and destination locations.
- Cleanup removes the owned locations' inventory posting setup, which native location deletion retains, so the same seed/cleanup cycle can be repeated.

### Fixed (2026-11-17) - Production reservation cancellation (#7, PR #213)

- Recreating a selected tracked reservation after cancellation clears the old partial reservation record before reading the result. Native tracking conversion can replace that record; the response now reports the created pair instead of failing a JIT field load after creation.

- Source-line cancellation now requires `sourceProdOrderLine` and `sourceSubtype` for production output (5406) and components (5407). Incomplete pointers return `MissingParameter` before writes; complete pointers preserve sibling lines and other production statuses. Native regression coverage and bilingual parameter help cover the required keys.


### Added (2026-11-16) - reserve tracked or selected inventory supply (#7)
- `Inventory.Reservation.Create` accepts optional `lotNo`, `serialNo` and `packageNo` filters. `itemLedgerEntryNo` reserves only the named open, positive supply entry after checking item, variant, location, tracking and unreserved quantity inside the native write transaction. An unavailable or conflicting selected supply leaves no reservation.
- Create now binds service lines, production order output and component lines, native-eligible transfer journal lines (including batch), and assembly headers through native source-specific reservation handling. Production pointers include the parent line. Serial requests require exactly one base unit.
- Get accepts the complete optional `sourceBatchName` and `sourceProdOrderLine` keys so identical journal/component line numbers in different batches/parent lines stay isolated.
- Existing general-supply partial-success responses remain compatible while the AC-6 contract decision is pending.
- BC 28/29 transfer posting reads the appropriate setup field without obsolete field references; test setup restores the same field.
- Added codeunit 10077030 `Reserv. Supply Filter ori`, bound only during selected-supply reservation; native BC retains its availability, warehouse and source-quantity checks. The table 337 write refusal now names the dedicated Create/Cancel types through Foundation's hint event. Changed codeunits 10076842, 10076843, 10076893, 10076901, 10076903 and test codeunits 96904, 96946 (17 additional tests), plus explicit test-only bilingual seed/cleanup actions in page/codeunit 96973.

### Added (2026-11-16) - read and cancel reservations by source line or entry (#7)
- `Inventory.Reservation.Get` reads by source line (`sourceType` + `sourceNo`, optionally `sourceSubtype` and `sourceLineNo`) or by `entryNo`, besides the item. Every source the Reserve action supports can be read. An unknown `entryNo` is refused as `RecordNotFound`. Each entry now also answers `variantCode`, `quantityBase`, `positive`, `sourceType`, `sourceSubtype`, `sourceBatchName`, `sourceProdOrderLine`, `sourceRefNo`, `lotNo`, `serialNo`, `packageNo`, `expectedReceiptDate`, `shipmentDate` and `creationDate`. The existing keys are unchanged.
- `Inventory.Reservation.Cancel` can cancel every reservation of one source line in one transaction (`sourceType`, `sourceNo`, `sourceLineNo`, plus `sourceBatchName` for an item journal line and `sourceProdOrderLine` for a production order component). A line without reservations answers Success with `entriesCancelled` 0. Both modes now answer `entryNos` and `entriesCancelled`. Cancelling by `entryNo` works as before.
- `Inventory.Reservation.Create` and the by-line `Inventory.Reservation.Cancel` refuse a sales line whose outstanding quantity is 0 with `PreconditionFailed`.
- No new objects: codeunits 10076842, 10076892, 10076893 and 10076894 and test codeunit 96946 (7 new tests) change.

### Added (2026-11-16) - Inventory valuation at a date (#109)

- `Inventory.Valuation.Get` returns quantity, actual cost, expected cost and total cost in LCY by item, location and variant, with posting-date cutoff, native filters and deterministic take/skip paging. Reads Value Entry amounts as report 1001 does; does not adjust costs or persist valuation rows.
- Adds temporary table 10077020 `Inventory Valuation Buffer ori`, codeunit 10077027 `Valuation Get Impl ori` and message enum value 10077027 (same ID as the codeunit), read/full role execution grants, localized help/refusals and test codeunit 96989. No product UI changes. The codeunit and enum value moved from 10077020 to 10077021 for #118, then to the next free ID 10077027 because main uses 10077021 for partial transfer receipt (#115). The temporary table stays 10077020; that ID is free for tables.
- Transfer posting/preview and their tests select the native direct-transfer setting at runtime: option field 5855 (0/1) on BC 28 or enum field 5857 (10/20) on BC 29. Both builds remain supported without referencing the deprecated field at compile time.
- Full-suite fixtures explicitly enable the attribute domain, and contract assertions include Foundation's common error-code response field from 28.0.13 while preserving exact application payload comparisons on earlier releases. Confirmation-boundary fixtures name a subject, as required by Foundation's current preview contract.


### Added - Standard cost worksheet (#121)

- Add `Inventory.StandardCost.Suggest` and `Inventory.StandardCost.Implement` with native worksheet suggestion and implementation, explicit unposted write effects, selected worksheet/journal responses, bilingual help and coded refusals with next steps. Implementation updates item/SKU costs; posting remains a separate revaluation operation.
- Add codeunits 10076933–10076937 and 10076938, enum extension 10076850 and test codeunits 96982–96983. Tests cover suggestions, revaluation creation without ledger posting, zero stock, replay, invalid input and bilingual contracts.
- Main-merge ID collision with Item Create (#130): `Std. Cost Suggest Impl ori` and `Inventory.StandardCost.Suggest` move from 10076932 to the next free codeunit and matching enum value 10076938. Enum extension `MsgType.StdCost.EnumExt ori` moves from 10076848 to the next free enum extension 10076850. `Inventory.StandardCost.Implement` stays on codeunit and value 10076933. Item Create keeps codeunit and enum value 10076932 and enum extension 10076848.

### Fixed - merge main into assembly reads (#225)

- Resolve the physical-inventory order ID collision by moving the PR's assembly read codeunits and message-type values from **10076960–10076961** to the next free IDs **10076965–10076966**. The enum extension ID remains **10076960**. Both features and all contract checks are retained; the combined Inventory catalogue has 65 types.

### Added — bounded requisition worksheets (#131)

- `Purchase.Requisition.Calculate` runs native report 699 with worksheet, item/location/variant filters and dates, replacing working lines only within the selected worksheet. `Purchase.Requisition.CarryOut` creates native purchase or transfer orders from all lines or an explicit selection and returns the actual order numbers.
- Implements Gunnar’s 16 November option A: reject Cancel, changes, rescheduling and existing-document links before any write; no printing, posting or existing-order edits. Calculate declares `write`; CarryOut declares `irreversible`, with bilingual help defining expectedCount as one worksheet selection. Native intermediate commits are suppressed and failures roll back.
- Added codeunits **10076941–10076945**, enum extension **10076849** (message values **10076941–10076942**), test codeunit **96947**; Full Access execute permissions and synchronized Icelandic XLF. Shared worksheet validation/serialization and the native event boundary are available for coordinated #117; its planning reports and API remain a separate implementation.

### Added (2026-11-16) - Inventory.ItemUnitOfMeasure.Create and Inventory.ItemUnitOfMeasure.Get (#100)

- `Inventory.ItemUnitOfMeasure.Create` (enum value and codeunit 10077012 `Item UoM Create Impl ori`, isolated write 10077013 `Item UoM Create Proc ori`) creates one new unit of measure on an existing item from `itemNo`, `code` (a unit of measure defined in Business Central), `qtyPerUnitOfMeasure` (greater than 0), and optional `length`, `width`, `height` and `weight`, and answers the saved unit. Effect `write` (not irreversible, not idempotent): a code the item already has is refused with `PreconditionFailed` and never changes its quantity per unit, and the refusal says so when item ledger entries use the unit; an unknown item or unit of measure code gives `RecordNotFound`. Every refusal carries a `nextStep` and saves nothing.
- `Inventory.ItemUnitOfMeasure.Get` (enum value and codeunit 10077011 `Item UoM Get Impl ori`) answers every unit of an item in code order, or one unit with `code`, with `isBaseUnit`, dimensions, cubage, weight and `hasLedgerEntries`, plus the item's `baseUnitOfMeasure`. Effect `read`.
- Enum extension 10077015 `MsgType.ItemUoM.EnumExt ori`. Both types are granted through `BIFROST InvRead ori` / `BIFROST InvWrite ori`; help in en-US and is-IS (is-IS.xlf regenerated). No Inventory Setup domain switch and no Data.Records write restriction were added, so existing generic writes keep working.
- Permissions: both types also require read access to Item Ledger Entry, so `hasLedgerEntries` and the ledger-entry refusal are never reported as absent for a caller who cannot read ledger entries; such a caller gets `PermissionDenied` with a next step. Create's help no longer claims generic writes are refused.
- Tests: `Item UoM Tests` (96984). `Inventory Contract Batch Tests` (96921) now counts 65 Inventory types (60 on main before the merge, plus the three physical inventory order types from #113 and the two Item UoM types from this PR).

### Added (2026-11-16) - native physical inventory orders (#113)

- `Inventory.PhysInventoryOrder.Create`, `.Finish` and `.Post` expose native calculation, recording creation, recorded quantities, finishing/differences and posting. Each call is atomic; Post returns the actual posted order number. Post declares `irreversible` and defines expectedCount as one order header in en-US/is-IS; Create/Finish declare `write`.
- Added implementation codeunits **10076960–10076962**, process **10076963**, contract **10076964**, enum extension **10076860** and test codeunit **96986**. Existing Full-role execute grants and Physical Inventory domain are reused. Bilingual discovery/help labels, Icelandic XLF, user documentation and the 62-type catalogue census are synchronized. Tests cover native success, zero count, bad input, repeat finish and rollback after a later recording failure.

### Fixed (2026-11-16) - physical inventory order regression checks (#113)

- Refusal tests assert the dispatcher's top-level code and nextStep fields. The irreversible-type boundary includes physical inventory order posting and distinguishes its optional handler count from Foundation's mandatory confirmation gate; both locale checks retain preview, mismatch and domain-refusal assertions. Product behavior and message contracts are unchanged.
- Owned-tenant regression checks use a unique separate posting series on every run, explicitly enable and restore Foundation's confirmation setting, and verify both raw attribute responses and Foundation's added shared response code. No object IDs added.

### Changed - Item application selectors and quantities (#40)

- Item application reads accept item, location and variant selectors and include both joined ledger entries. Unapply accepts a ledger entry and atomically uses the native worksheet path for its real applications. Reapply accepts outbound/inbound entries and an exact positive base quantity, with native checks and rollback on a mismatch. Existing parameter forms remain supported.
- Items and affected entries remain marked for cost adjustment after unapplication; adjustment stays a separate operation.
- Added codeunit **10077034** (`Item Appl. Quantity ori`) and test codeunit **96994** (`Item Application 40 Tests ori`). Added bilingual help, synchronized is-IS translations and regression tests. The requested `DomainDisabled` error is pending Foundation support; current domain refusals retain `InvalidParameter`.
### Added (2026-11-16) - Inventory.SKU.Create and Inventory.SKU.Get (#114)
- `Inventory.SKU.Create` runs the Create Stockkeeping Unit report (5706) from `itemFilter`, `locationFilter`, `variantFilter`, `createPer`, `itemInInventoryOnly` and `replaceExisting`, and answers `itemsMatched`, `created` and `skuCount`. Effect: write (replaceExisting overwrites units edited by hand).
- `Inventory.SKU.Get` reads stockkeeping units with planning and cost fields (exact itemNo, locationCode, variantCode; at most 500 rows). Effect: read.
- Data.Records.Set on table 5700 is refused and names the two types. Both types use the Availability domain switch.
- Objects: codeunits 10076995 `SKU Create Impl ori`, 10076996 `SKU Get Impl ori`, 10076997 `SKU Create Proc ori`, 10076998 `SKU Request ori`, 10076999 `SKU Restrict ori`; enum extension 10076995; tests 96968 `SKU Tests`, 96999 `SKU Perm`. is-IS help and translations included.

### Added (2026-11-16) - purchase return from posted lines (#137)

- `Purchase.ReturnOrder.CreateFromPosted` (codeunit 10076930 `Purch. Return Create Impl ori`, enum extension 10076847) creates an open purchase return order or credit memo, or adds lines to an existing open one, from posted receipt or invoice item lines. The copy uses the same exact-cost path as Posted Purchase Document Lines. Each new item line keeps Appl.-to Item Entry. A partial quantity is stored when the posted line applies to one item entry. Nothing is posted. A quantity above the quantity left to reverse, a line of another vendor, a non-item line, a duplicate posted line, and a partial quantity on a line split across several item entries answer `InvalidLine` with a next step before any write. Missing, unknown and badly typed keys, a missing vendor or posted line, a vendor that does not match an existing document, a document that is not open, and more than 200 lines answer the matching coded refusal.
- Purchase Returns is domain value 16 and Inventory Setup field 26. The main-merge conflict with Item Substitution keeps its value 15 and field 25; Purchase Returns takes the next free IDs and wizard slot 17. A purchase header whose document type is Return Order or Credit Memo turns it on for a new setup row and for the existing usage upgrade. The setup page and the setup wizard show the switch. Execute permission is on `BIFROST InvWrite ori`. The effect is write, not irreversible, so the call does not ask for a confirmation count.
- Tests: `Purch. Return Create Tests` (96980) covers the full receipt return, the quantity refusal, the other-vendor refusal, a partial credit memo from a posted invoice, appending to an existing return order, zero and duplicate lines without writes, typed input refusals, bilingual help and next steps, and the three-part type name. `Inventory Domain Usage Tests` (96963) covers the new usage signal and clears purchase headers in that fixture. Bilingual refusal tests pass the LCID explicitly through the dispatcher so the configured default language cannot mask the Icelandic assertion.
### Fixed (2026-11-16) - assembly read CI regressions (#225)
- Assembly read discovery returns disabled when the caller cannot read Inventory Setup, matching execution's coded permission refusal.
- Assembly tests use a future shipment date for ATO fixtures and the normal dispatcher for the Icelandic unknown-key refusal. Restrictive permission assertions remain unchanged.

### Added (2026-11-16) - Inventory.AssemblyToOrder.Get and Inventory.AssemblyBOM.Get read assemble-to-order links and assembly BOMs (#116)
- New message type `Inventory.AssemblyToOrder.Get` (enum value 10076960; codeunit 10076960 `Asm. To Order Get Impl ori`). It takes a sales line (`documentType` Quote, Order or Blanket Order, default Order; `documentNo`; `lineNo`) and answers the assembly order linked through the Assemble-to-Order Link (table 904): `linked`, the assembly header in `assemblyOrder` and its `lines`. A sales line without a link answers `linked: false`.
- New message type `Inventory.AssemblyBOM.Get` (enum value 10076961; codeunit 10076961 `Assembly BOM Get Impl ori`). It takes `itemNo` and the optional `explode` (off by default) and answers the BOM Component (table 90) lines with `level`, `parentItemNo`, `quantityPer` and `totalQuantityPer` (multiplied through the levels per base unit of the item). A component already on its own branch is not exploded again.
- Both are in enum extension 10076960 `MsgType.AsmRead.Ext ori`, are gated by the existing Assembly domain, and declare their real effect: `read`, nothing changed, idempotent (core#1365 D1). `BIFROST InvRead ori` and `BIFROST InvWrite ori` execute both codeunits.
- Refusals: `MissingParameter`, `InvalidParameterFormat`, `UnknownParameter`, `RecordNotFound`, `InvalidParameter` (Assembly domain off), `PermissionDenied`, each with a `nextStep`; help and refusals in en-US and is-IS (XLF regenerated).
- Tests: `Assembly Read Tests` (96966) and `Assembly Read Perm` (96967); `Inventory Contract Batch Tests` counts 61 app types (45 in the scoped census).
### Fixed (2026-11-16) - BC 29 Direct Transfer compatibility (#228)

- Codeunits 10076901 and 10076903 use the replacement Inventory Setup `Direct Transfer Posting Type` enum when compiled with `BC29`. The default branch retains the BC 28.5 option field because that version has no replacement enum. Posting choices and message contracts are unchanged; no warnings are suppressed.
- Test helper 96904 sets and restores the matching field for each target. Existing preview tests 96912 cover both posting modes; tests 96914 retain partial shipment/receipt coverage and add single-document direct-transfer posting coverage. No new object IDs or user-facing text.
- For BC 29 symbol builds, pass `/define:BC29` to **both** the product and test compiler invocations. For BC 28.5 builds, omit it. See `docs/development/direct-transfer-compatibility.md`.
- Merge resolution (2026-11-17): main’s PR #213 runtime field detection supersedes the compile-time branches above while preserving both posting choices and the single-document regression test. Neither target now requires a compiler define. The build guide reflects this resolution.
### Fixed (2026-11-16) - physical inventory blank-row parity (#186)

- Check and PreviewPost now use Post's existing empty-row filter in `Inventory Native Journal ori` (10076840). Rows without an item and with all three quantity fields zero are ignored after applying the requested selection; nonempty missing-item rows keep the native typed refusal.
- Added test codeunit 96964 `Inv. 186 Blank Line Tests ori`: eight bilingual dispatcher tests cover mixed batches, explicit subsets, blank-only selections, all three nonzero quantity fields, preview rollback and actual posting parity. No new product objects or user-facing text.

### Added (2026-11-16) - Item substitutions (#118)

- `Inventory.ItemSubstitution.Get` reads direct native substitutions for an item and exact variant, with current on-hand inventory in base units. Catalog substitutes report unknown inventory explicitly; the call never updates cached quantities or creates items. Includes coded refusals, bilingual discovery/help labels, and an Item Substitution switch on Inventory Setup and its read-only guide.
- Added codeunit **10077020** `Item Subst. Get Impl ori` and test codeunit **96993** `Item Substitution Tests ori`. Extended enum 10076840, domain enum 10076835 (value 15), setup table 10076836 (field 25), setup pages and read permission extension. No existing contract was changed.
### Changed (2026-11-16) - native filter contract for Adjust Cost and Cost to G/L (#35, partial)
- `Inventory.AdjustCost.Run` (codeunit 10076858 / 10076859) refuses both filters together and invalid filters before report 795 runs, without writes. `postingDate`, `inventoryPostingGroup` and `itemByItem` are not parameters and are refused as `UnknownParameter` (`itemByItem` stays a documented gap: code cannot set that request-page option on this build). The answer now carries `itemsProcessed` (items the filters select) and an `errors` array (empty on success).
- `Inventory.CostToGL.Post` (codeunit 10076863, `Inventory Write Process ori`) no longer binds `documentNoFilter`: the document number of report 1002 is an output option, not a selection filter, so it is refused as `UnknownParameter`. A real `postingDateFilter` on the pending entries replaces it, in the request and the answer. The response field `documentNoFilter` is replaced by `postingDateFilter`.
- Not done yet: `Inventory.CostToGL.Test` still counts items and does not run report 1003; `perPostingGroup` and the 1003 mandatory-template path stay pending. No object IDs added; tests added to codeunit 96960 range files (no new test objects). is-IS translations added.

### Fixed (2026-11-16) - PR #214 review amendments
- Confirmation native-success tests allocate owned GUID locations and G/L accounts, avoiding collisions with padded test-library account numbers without deleting or changing existing accounts.
- Follow-up: handlers reject unsupported costing controls before native execution even with the pinned legacy Foundation. Contract regression expectations include the full confirmation-count help and the current scheduled-versus-synchronous error distinction.
- AdjustCost help distinguishes scalar-format refusals from the `InvalidParameter` selection refusals raised before report 795. Both costing types explain in English and Icelandic that confirmation of a named subject counts one run, not selected items or value entries, and disclose Foundation's unnamed-request behavior.
- Contract tests retain exact app response descriptors while validating Foundation's shared conditional error-code descriptor. Confirmation tests exercise both unnamed handler validation and named-subject preview/mismatch/success, matching Foundation #1278. Regenerated the Icelandic translation file from the compiler output, including the CostToGL `UnknownParameter` wording. No runtime execution, message contract or object ID changed.
### Added (2026-11-16) - Inventory.TrackingInfo.Get reads lot, serial and package information cards (#106)

- New read-only message type `Inventory.TrackingInfo.Get` (effect `read`). Select an item (subject, `itemNo`, item SystemId or `tableView`), the `variantCode` of the card and exactly one of `lotNo`, `serialNo` or `packageNo`. It answers the Lot No. Information (6505), Serial No. Information (6504) or Package No. Information (6515) card: `description`, `testQuality` (lot only), `certificateNumber` (lot and package), `countryRegionCode` (package), `blocked`, `hasComments`, the item tracking `comments`, `inventory` and `expiredInventory` (expiration date before the work date), all in base units.
- Refusals: `MissingParameter` on `itemNo` or on `lotNo|serialNo|packageNo`; `InvalidParameter` when more than one tracking number is sent; `InvalidParameterFormat` for a value that is too long or not a string; `RecordNotFound` with nextStep "The tracking number has no information card..." when the card does not exist (also when the number has stock); `PermissionDenied` per table. Help and refusals are in en-US and is-IS.
- Objects added: enum extension 10076915 `MsgType.TrackInfo.EnumExt ori` (value 10077010), codeunit 10077010 `Tracking Info Get Impl ori` (granted X in `BIFROST InvRead ori`). Test app: codeunit 96992 `Tracking Info Get Tests` (8 tests); 96921 registers 72 Inventory types.
### Fixed (2026-11-16) - physical inventory coded refusals (#154)

- Wrong-template and recurring-template selections now return `InvalidParameter` and `PreconditionFailed` on `templateName` with fully localized errors and next steps, for Calculate, RecordCount, legacy Record, Check, PreviewPost and Post. Shared batch and count help entries name the runtime codes in both languages; nested unsupported count keys preserve their actual received value.
- Test fixture codeunit/page 96973 can explicitly seed only the owned issue154 journals and unposted count item for MCP verification; no fixture runs on install and the change log write guard is unchanged.
- Existing codeunits 10076840, 10076880–10076885 and tests 96921/96944/96975/96978 are extended; no object IDs added. Bilingual native regressions cover malformed counts, selectors, templates, help and unchanged owned journal data. Dispatch tests pass LCID explicitly; confirmation tests enable their own required confirmation setting, and attribute parity includes the Foundation 28.0.13 shared response code descriptor.

### Fixed ([28.3.2.0] development)
- #119 merge compatibility: moved `Nonstock Item Create Proc ori` from codeunit 10077021 to free codeunit 10076947, preserving main's `Transfer Receive Impl ori` and the catalog message contract. The merged registry test retains both item-creation types and checks all 72 Inventory registrations.
- #114: `Inventory.SKU.Create.created` counts new SKU keys independently of removals when `replaceExisting` changes the SKU set. Added regressions for replacement with no variants and replacement of two location keys by one variant key. Attribute contract tests retain exact app-owned response comparisons while accepting Foundation’s appended error-code descriptor (focused #207 correction).
- #37: native tracking supports assembly output/components and item journal lines; Delete accepts source-bound entry numbers or all unreserved source tracking, validates the entire selection before removal, and counts duplicate entry numbers once. Fractional deletion entry numbers are refused before AL can round them to an existing entry. Discovery and execution share the tracking permission gate. Updated objects: codeunits 10076841, 10076897-10076899, 10076925; tests 96970 and 96974; explicit owned MCP seed/cleanup actions in test objects 96973; domain gate 10076922. No new object IDs. Disabled tracking writes return PreconditionFailed with bilingual setup recovery guidance, per the corrected #37 acceptance criterion (Claude Code, 16.11.2026).

### Fixed (2026-11-17) - Inventory.NonstockItem.Create native refusal recovery (#119)

- A native refusal from catalog item creation (for example an item number series with no usable line) now sets the error context before the write, so `BusinessCentralError` includes the documented `nextStep`. Omit Commit still lets that error propagate. `Nonstock Item Create Tests` (96934) covers the refusal and that nothing is saved.

### Added (2026-11-16) - Inventory.NonstockItem.Create (#119)
- Conflict repair: main keeps Item Substitution domain value 15, setup field 25 and codeunit 10077020. Catalog Items moves to the next free domain value 16, setup field 26 and process codeunit 10077021; its setup guide uses a separate display slot. Both domains and message contracts are preserved. Domain-usage assertions and setup loops follow Catalog Items field 26. Registry assertions expect the combined 61 Inventory types, retaining both features.
- New message type `Inventory.NonstockItem.Create` (codeunit 10077019 `Nonstock Item Create Impl ori`, process codeunit 10077021 `Nonstock Item Create Proc ori`, enum extension 10077019 `MsgType.Nonstock.EnumExt ori`). It takes `data.entryNo` of a catalog item (table 5718 `Nonstock Item`), creates the item through codeunit 5703 `Catalog Item Management` with the catalog item's own item template, and answers the new `itemNo` and `itemId`. Effect `write` (not idempotent, nothing posted).
- Refusals answered before anything is written: `MissingParameter`, `InvalidParameterFormat`, `UnknownParameter`, `InvalidParameter` (too long, domain off), `RecordNotFound` (no catalog item), `PreconditionFailed` (already turned into an item; no vendor, vendor item number, unit of measure or existing item template; no Catalog Item Setup; no item number series; the number it would get already belongs to an item), `PermissionDenied`. Each has a `nextStep`, help and refusal texts are in en-US and is-IS (`Bifrost Inventory.is-IS.xlf` regenerated).
- New domain `Catalog Items` (`Inventory Domain ori` value 17, `Inventory Setup ori` field 27, Inventory Setup page and setup guide slot 18, after purchase returns kept value 16 and field 26). New rows enable it when the company has catalog items; existing rows get it once through the new per-company upgrade tag `Origo.Bifrost.Inventory-CatalogItemsUsage-20261116`, which raises only this switch.
- Tests: `Nonstock Item Create Tests` (96934) and three Catalog Items cases in `Inventory Domain Usage Tests` (96963).
### Added (2026-11-16) - Inventory.Item.Create creates an item from an item template (#130)
- Main-merge ID collision: Item Create takes codeunit and message enum value 10076932 (formerly 10076930) and enum extension 10076848 (formerly 10076847), preserving the Purchase Return IDs already on main. Item Create process codeunit 10076931 is unchanged.
- New message type `Inventory.Item.Create` (enum value 10076932 in enum extension 10076848 `MsgType.ItemCreate.EnumExt ori`; codeunits 10076932 `Item Create Impl ori` and 10076931 `Item Create Proc ori`). It takes `templateCode` plus the optional `description`, `baseUnitOfMeasure`, `unitPrice` and `gtin`, creates the item through Microsoft's `Item Templ. Mgt.` (codeunit 1336) so the template's base unit of measure, posting groups, costing method and number series apply, and answers `itemNo` with the item's `unitsOfMeasure`.
- Refusals: unknown template `RecordNotFound`; a base unit of measure that does not exist `InvalidParameter`; missing or empty `templateCode` `MissingParameter`; wrong JSON types `InvalidParameterFormat`; unknown keys `UnknownParameter`; texts longer than their field or a negative `unitPrice` `InvalidParameter`; no permission `PermissionDenied`. Each refusal carries a `nextStep`; help and refusals are in en-US and is-IS (XLF regenerated).
- The contract declares its real effect (`write`, does not post, not idempotent; core#1365 D1). The type is not irreversible, so no `expectedCount`. It is gated by the existing Attributes domain on Inventory Setup (item and attribute management); no new setup field.
- `BIFROST InvWrite ori` executes both new codeunits. Tests: `Item Create Tests` (96960) and `Item Create Perm` (96961); `Inventory Contract Batch Tests` counts 61 app types and checks the new contract's parameters and examples.
### Added (2026-11-16) - Partial transfer shipment and receipt (#115)
- Merge compatibility: moved `Transfer Ship Impl ori` and its `Inventory.TransferOrder.Ship` enum value from 10077020 to the next free ID 10077026 because main assigns 10077020 to Item Substitution (#118). Message names and behavior are unchanged.

- `Inventory.TransferOrder.Ship` and `Inventory.TransferOrder.Receive` post the requested quantities on selected lines and return the posted shipment or receipt number. Invalid, duplicate and excessive quantities return `InvalidLine` with a next step before changes. Native failures roll back the quantity edits and posting. Both operations declare an irreversible effect and explain in English and Icelandic that `expectedCount` counts one transfer order.
- New codeunits 10077021–10077024 and 10077026 implement the operations, atomic posting process and bilingual contracts; test codeunit 96969 covers partial and final posting, omitted lines, invalid input, rollback and help.
- New codeunit 10077025 reads direct-transfer posting setup on BC 28 and BC 29. Existing Post and PreviewPost retain their behavior while using the replacement BC 29 setting without obsolete field references.
### Added
- #135: `Price.List.Set` maintains Draft sales and purchase price-list headers and numbered lines using native validation. `Price.List.Activate` verifies all lines and refuses native duplicate prices with conflicting list/line identifiers before native activation. Generic writes to tables 7000/7001 are blocked. Both types declare `write`, include en-US/is-IS help and coded recovery guidance. Codeunits **10076980–10076984**, enum extension **10076980** (values **10076980/10076981**); tests **96987**.

### Fixed (2026-11-16) - price-list unknown-key validation (#135)
- Price-list validation returns `UnknownParameter` for undeclared header, line and activation keys, including on Foundation versions that do not reject them before execution. Direct validator regressions preserve exact refusal codes and recovery guidance alongside the dispatcher tests.

### Added (2026-11-16) - Sales.ReturnOrder.CreateFromPosted (#136)

- New message type `Sales.ReturnOrder.CreateFromPosted` (enum value 10077032 in enum extension 10076906 `MsgType.SalesRetOrd.Ext ori`; codeunits 10077032 `Sales Ret. Ord. Post. Impl ori` and 10077033 `Sales Ret. Ord. Post. Proc ori`). It creates a sales return order or credit memo, or fills an open one, from posted sales invoice or shipment lines with quantities, through native codeunit 6620 `Copy Document Mgt.` (`SetProperties` with exact cost reversal, `CopySalesInvLinesToDoc`, `CopySalesShptLinesToDoc`), the same routine as Get Posted Document Lines to Reverse, so item lines get Appl.-from Item Entry.
- Request: `documentType` (`ReturnOrder` or `CreditMemo`), `customerNo` for a new document or `documentNo`/`systemId` for an existing open one, and `lines` of `{source (Invoice|Shipment), documentNo, lineNo, quantity}`. The answer gives the document no., `created`, and the added lines with `applFromItemEntryNo`. A quantity above what is left to reverse (shipped quantity not yet returned for item lines) and a line of another customer are refused with `InvalidLine`, a released document with `PreconditionFailed` (pointing to `Sales.Document.Reopen`); every refusal has a Bifröst code and `nextStep` and nothing is created.
- Effect `write` (not irreversible; nothing is posted and the document can be deleted while open), `posts: false`, `idempotent: false` (core#1365 D1). Help, refusals and examples in en-US and is-IS; is-IS.xlf regenerated with `tools/Update-IcelandicXlf.ps1`.
- `BIFROST InvWrite ori` grants X on the two new codeunits. Tests: new codeunit 96991 `Sales Ret. Ord. Post. Tests` (new return order from an invoice line with item entry link, credit memo from a shipment line, quantity above remaining, same line twice, other customer, released document, coded invalid input, bilingual help).

### Fixed (2026-11-16) - Sales.ReturnOrder.CreateFromPosted build and write order (#136)

- Line paths passed to `StrSubstNo` are Locked labels, so AppSourceCop AA0217 no longer warns on the implementation.
- The posted lines are collected again before any header is created. A refusal on that pass leaves the coded error and creates nothing.
- The implementation, process codeunit and message-type value are 10077032 / 10077033 / 10077032, and the test codeunit is 96991, clear of the ids taken by earlier open pull requests. Enum extension 10076906 is unchanged.
### Added (2026-11-16) - Inventory.ItemVariant.Create and Inventory.ItemVariant.Get (#99)

- `Inventory.ItemVariant.Create` (enum value and codeunit 10076991 `Item Variant Create Impl ori`, isolated write 10076992 `Item Variant Create Proc ori`) creates one new variant on an existing item from `itemNo`, `code`, `description`, `description2` and `blocked`, and answers the saved variant. Effect `write` (not irreversible, not idempotent): a second call with the same code is refused with `PreconditionFailed`, an unknown item with `RecordNotFound`; every refusal carries a `nextStep` and saves nothing.
- `Inventory.ItemVariant.Get` (enum value and codeunit 10076990 `Item Variant Get Impl ori`) answers every variant of an item in code order, or one variant with `code`. Effect `read`. An item without variants answers an empty `variants` array.
- `Item Variant Restrict ori` (10076993) refuses generic `Data.Records.Set` writes to table 5401 `Item Variant` and names the dedicated types; reads stay allowed.
- Enum extension 10076890 `MsgType.ItemVar.EnumExt ori`. Both types are granted through `BIFROST InvRead ori` / `BIFROST InvWrite ori`; help in en-US and is-IS (is-IS.xlf regenerated). No Inventory Setup domain switch was added: the types follow the caller's item and item variant permissions.
- Tests: `Item Variant Tests` (96988). `Inventory Contract Batch Tests` (96921) counts 79 Inventory types after merging main (the two Item Variant types plus the types already registered on main, including the two Item unit of measure types and the two Planning Worksheet types).
### Fixed (2026-11-16) - selected transfer shipment undo and assembly recreation (#39)

- `Inventory.Transfer.UndoShipment` accepts optional `lineNos` (1–100 distinct positive posted line numbers). It validates the complete selection before native undo, refuses missing or already-corrected lines, and preserves unselected lines. Omission retains all non-correction lines.
- `Inventory.Assembly.UndoPost` accepts a JSON boolean `recreateOrder`, default false, and passes it to native `Assembly-Post.Undo` within the existing atomic transaction.
- Confirmation parameters stay owned by Foundation; bilingual count units remain in effect help. Assembly undo builds a separate request containing only the validated recreation flag for its isolated writer, retaining public setter compatibility. No object IDs added.
- Foundation currently builds contract chapters in English even at LCID 1039. Count definitions therefore include both en-US and is-IS wording in the source text; translated XLF targets remain synchronized.
- All three changed irreversible contracts (shipment undo, assembly undo and transfer posting) explain in en-US and is-IS that `expectedCount` counts one posted document, not lines or entries. The receipt compatibility identifier remains disabled: neither the BC 28 source nor BC 29 symbols contain a native receipt undo.
- BC 28/29 transfer posting and preview read the applicable setup field by ID; BC 29 uses enum field 5857 rather than the obsolete option field 5855. Existing direct-transfer tests cover both posting modes.
- No object IDs added. Changed product codeunits: 10076842, 10076901, 10076903, 10076909, 10076910. Regression tests extend 96909 and 96914; explicit owned MCP setup and cleanup (including native Inventory Posting Setup rows for the owned locations) extend test codeunit/page 96973 and helper 96904.
- Regression 96914 checks the bilingual one-document count in effect help and in the examples. It does not require the app to declare `expectedCount`; Foundation owns that parameter.
### Changed (2026-11-16) - Reclassification journal check, preview and post use the native journal path (#34)

- Corrected selector precedence, native validation/subset help and bilingual confirmation guidance: `expectedCount` confirms one journal batch operation (always 1), independently of selected line and ledger counts. Posting and preview refuse non-Transfer entries inside a Transfer template. Source warnings are fixed. The existing same-repository BC 28/29 direct-transfer setting adapter is retained in 10076901/10076903 to compile against BC 29 without raising the application floor. Tests remain in 96964; no object IDs added.

- `Inventory.Reclassification.Check` (10076887) validates every line of the Transfer batch with the standard Item Jnl.-Check Line and answers `validationResult` (Ready, ReadyWithWarnings, NotReady), `lineCount`, `errorCount`, `warningCount`, `errors` and `warnings`; `postedLineCount` is kept as an alias of `lineCount`. `Inventory.Reclassification.Post` (10076888) and `PreviewPost` (10076889) go through the same native journal helper (10076840 `Inventory Native Journal ori`), accept `templateName`/`batchName` as well as the journal aliases, and take an optional `lineSystemIds` array to work on a subset of the batch. Post returns `itemRegisterNo`, `postedLineCount` and a per-line `result` (from/to location, bin, lot, serial, package, tracking). Non-Transfer templates are refused with `PreconditionFailed`. The earlier response keys (`journalTemplateName`, `journalBatchName`, `lineCount`, `lines`) are kept. No object IDs added; tests in codeunit 96964.

### Fixed (2026-11-16) - Attribute contract tests accept the Foundation error code descriptor (#205)
- Foundation core #1345 (merged 14.11) appends the conditional error `code` descriptor to every published response chapter. Codeunit 96921 compared the whole response JSON and failed on four Attribute types (Get, Create, Update, AttributeDefinition.Create). The response check now requires every app-owned field to match exactly and in order, and allows only the one trailing Foundation `code` field. No product code and no object IDs changed.


### Fixed (2026-11-14) - AttributeDefinition.Create keeps the documented optionValues contract (#151)
- `Inventory.AttributeDefinition.Create` checks `optionValues` only when `type` is Option, as the help says. Plain JSON values (strings, numbers, booleans) are used as text, and entries that are not plain values (objects, arrays, null) are skipped again, as on the released contract. Empty, duplicate (not case-sensitive) or longer than 250 characters values are refused with `InvalidParameter` before anything is created.
- Callers that sent JSON numbers or booleans for the string keys of `Inventory.AssemblyOrder.Create`, `Inventory.TransferOrder.Create`, `Inventory.Assembly.UndoPost` and the Transfer `postingType` now get `InvalidParameterFormat` on that key (earlier releases coerced them to text). Send those keys as JSON strings, as the help declares.
### Fixed (2026-11-09) - compose current help with coded refusals (#148, #155)

- Icelandic posting-permission guidance uses the existing localized caption Bókunarhlið birgða; English uses Inv. Posting Gate. Exact bilingual permission-denial tests remain.
- Keep one MissingParameter help entry for TransferOrder.Post/PreviewPost: the shared entry covers the identifier and postingType; remove the duplicate postingType-only declarations. The exact one-entry assertion remains.
- Reconcile composed strict tests (96918, 96921, 96922): current permission captions, all five Attribute.Get help entries, and exactly one combined MissingParameter entry including postingType. No assertion is disabled or skipped.
- Merge parent #166 through `b364159` into #168, retaining current help captions and permission-set identifiers alongside the bilingual coded refusals in codeunits 10076844, 10076887, 10076888, 10076889, 10076868 and 10076869. Keep the current attribute overwrite guidance and exact bilingual assertions in 96930, and retain the child malformed-array and atomic-write contracts. Parent hold and post-deployment UAT remain pending.

### Fixed (2026-11-09) - refusal help regressions after merging main (#151)

- Restore the duplicate-definition help code to `PreconditionFailed` in codeunit 10076919, matching the request preflight in codeunit 10076913; the native resolver remains unchanged. Test codeunit 96922 counts every matching error code, preserving strict uniqueness of the combined identifier and `postingType` entry in both languages.
- Live MCP found that the shared item-number resolver (10076919, used by Reservation.Get and Cost.Get) accepted JSON booleans and omitted `received` for objects/arrays or a missing required selection. Those typed refusals now preserve the received value. String, numeric and optional-null selection behavior remains compatible; bilingual regressions in codeunit 96975 create their own numeric item to verify compatibility.

### Fixed (2026-11-09) - keep typed Inventory refusals on current main (#151)

- Merge main `25aa5a1` (#175 / #152) into the refusal contract. Main keeps field-write checks, help captions (`Inv. Posting Gate`, `Full Access`) and `effect.permissionSet` IDs. #151 keeps typed refusal codes and parameter, expected and nextStep on the refusal paths in codeunits 10076854, 10076858, 10076859, 10076863, 10076866, 10076881, 10076882, 10076883, 10076893, 10076901, 10076902, 10076903, 10076909 and 10076919, and in test codeunit 96921. Duplicate attribute names are refused by the typed preflight before the native resolver runs. `pr:on-hold` on PR #166 is unchanged.

### Fixed (2026-11-14) - AppSource gate accepts a baseline-reused product (#190)

- AppSource build gate (`tools/Assert-AppSourceBuild.ps1`, `tools/appsource_gate.py`, `tools/AppSourceBuildGate.md`): ported from attachments #219. When a PR does not touch `app/` and AL-Go incremental builds reuse the baseline product package, Finalize/Pipeline accept it instead of a current-run `app` compile receipt, only if `_baselineWorkflowRunId` is numeric, `_baselineWorkflowSHA` is a 40-hex SHA, and exactly one `.buildartifacts/Apps/*.app` has that NAVX `sourceCommit` and the identity in `app/app.json`. Test-mode BeforeCompile seeks reuse only for the test app. `app/` touches, missing evidence and Signed stay fail-closed. New `ProductReuse` tests in `tools/tests/test_appsource_gate.py` use this repo's own app and test-app IDs. Incremental builds stay enabled; no AL change.
### Fixed (2026-11-05) - Reservation.Cancel RecordNotFound refusal (#169)

- `Inventory.Reservation.Cancel` (10076892, `Reservation Cancel Impl ori`) answers `RecordNotFound` for an absent `entryNo` with `expected` (a positive JSON integer) and an actionable `nextStep` that points to `Inventory.Reservation.Get`, as the #151 refusal contract requires. `Reservation Create Tests` (96946) `Cancel_UnknownEntry_ReturnsRecordNotFound` asserts `received`, `expected` and `nextStep`. No public procedure or field changed.

### Fixed (2026-11-13) - cost and price tests pass for users with a Full Name (#188)

- `Inventory Cost Write Tests` (96937) `UpdateCost_RestrictedField_PreservesAllFields` and `UpdatePrice_RestrictedField_PreservesPrice` in `Inventory Price Write Tests` (96939) typed `UserId()` into the Foundation field-access page, which looks the name up by Full Name and only matched users without one. The tests now type the name the User/App buffer shows for the current user (Full Name, else User Name), read from the User table because the buffer table is internal to Foundation. Test app only; no product change and no object IDs added.

### Fixed (2026-11-06) - Issue 152 review amendments

- `Inventory.Tracking.Get` (codeunit 10076900) and `Inventory.Tracking.Availability.Get` help no longer mention a `quantity` input, and `Inventory.TransferOrder.Statistics` (codeunit 10076905) no longer promises a reservation state that the response does not have; the `Transfer Order Stats Impl ori` description label and its is-IS translation are corrected.
- `effect.permissionSet` again holds one assignable permission set ID (`BIFROST Full ori` or `BIFROST Read ori`) on every Inventory type, the same shape as Foundation. The help-text guard (96970 `NotesAndOverview_NameNoAlObjects`) exempts that single structured field; captions such as Inv. Posting Gate stay in the error and notes text.

### Fixed (2026-11-06) - compose coded refusals with the current parent (#148, #155)

- Merged PR #166 into the existing #168 candidate. `Item Appl. Get Impl ori` (10076867) retains #166's entry-number parser, `InvalidParameter` format refusal and optional metadata, per Claude's composition disposition. Its help declares that retained code. The four bilingual Get refusal cases in `Inventory Item Refusal Tests` (96930) assert that exact parent shape; Unapply/Reapply and Inventory-owned refusal checks remain intact. Attribute help and the child's localized domain-denial completion remain present. The inherited malformed-array parity tests in `Item Attribute Tests ori` (96900) now assert issue #148's `InvalidLine`, parameter, expected shape and exact bilingual next step, alongside the existing exact error text.

### Fixed (2026-11-05) - unknown journal keys follow Foundation's shared refusal (#151)

- Test codeunit 96975 `Inv. Typed Refusal Tests ori`: the `*_UnknownParameterCoded_*` tests for the non-read types Inventory.PhysInventory.Calculate, Inventory.PhysInventory.RecordCount, Inventory.PhysInventory.Post and Inventory.Revaluation.Post expect Foundation's shared `UnknownParameter` code when Foundation 28.0.10 or later refuses unknown request keys before Inventory runs (core#1160). The read types Inventory.PhysInventory.Check and Inventory.Revaluation.PreviewPost still expect Inventory's own `InvalidParameter`. The eight Foundation-owned unknown-key cases retain parameter, expected and nextStep checks; the received assertion awaits Foundation [#1277](https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/issues/1277), per the acting Architect’s PR #166 ruling on 2026-11-05. Inventory-owned refusals keep all received assertions.

### Fixed (2026-11-04) - isolate native refusal test requests (#151)

- `Inv. Typed Refusal Tests ori` (96975) starts each journal-context invocation with a fresh request. A posting call's helper-added `expectedCount` no longer reaches the following read-only preview. All native error, context and no-write assertions remain unchanged.

### Fixed (2026-11-03) - merge main contract-parity fixes into the help branch

- Merge main `c667066` (#159 / #179) and keep the #152 display captions on assembly and transfer notes in `Inventory Contract Parts ori` (10076919). The assembly preview note keeps main's rollback sentence for `postingDate` and `quantityToAssemble`.
- `Inventory.ItemApplication.Get` (10076867) keeps main's `InvalidParameter` when `itemLedgerEntryNo` is not a JSON integer.
- Unused codeunit `Phys. Invt. Calc Impl ori` (10076880) stays deleted. `Inventory.PhysInventory.Calculate` remains on `Phys. Inv. Calc Impl ori` (10076883).
- Contract batch tests (96921) keep main's rule: the shared `Retryable` row is required only when installed Foundation is 28.0.11 or newer. Transfer posting tests (96914) still send `expectedCount` only when the composed contract declares it.

### Changed (2026-11-03) - Help links guard runs in Source Guards (#31)

- Source Guards runs `tools/Test-HelpLinks.ps1` (unchanged) in a new `HelpLinks` job against the current `businesscentralal/bifrost` main, so every page must link to a help page that exists in both en-US and is-IS. The job logs the documentation revision it checked. Workflow change only, no app change.

### Fixed (2026-11-03) - preview adjustments and period help (#159)

- `Inventory.AssemblyOrder.PreviewPost` (10076849) applies `postingDate` and `quantityToAssemble` inside the posting preview, through `Asm. Preview Adjust ori` (10076929) on `Assembly-Post.OnBeforeOnRun`. The preview rolls that write back, so the stored posting date and quantity to assemble stay unchanged and the call does not Commit. `Asm. Doc Prev. Post Tests` (96905) previews an order that has lines with both keys and checks the order afterwards.
- Renumbered the internal preview adjustment helper from 10076926 to 10076929 to avoid the earlier `Inventory Read Process ori` allocation in #151 / PRs #166, #168 and #171. No public procedure or message contract changed.
- `Inventory.Period.Close` (10076877) and `Inventory.Period.Reopen` (10076879) help now says the checks and writes of Close Inventory Period (5820) are reproduced and that 5820 is not run, so `OnRunOnBeforeCheck` is not raised. Notes and overview do not name an AL object. Reopen no longer says a platform refusal writes nothing. Icelandic notes are in the is-IS translation.

### Fixed (2026-11-02) - remaining contract-parity defects (#159)

- Removed the unused codeunit `Phys. Invt. Calc Impl ori` (10076880). `Inventory.PhysInventory.Calculate` stays on `Phys. Inv. Calc Impl ori` (10076883). No message type pointed at 10076880.
- `Inventory.TransferOrder.Post` (10076903) refuses `ShipReceive` on a non-direct transfer and the error text no longer lists that value as valid. `Transfer Order Post Tests` (96914) covers the refusal.
- `Inventory.AssemblyOrder.Release` (10076851) traps the native release with `Codeunit.Run`, including the Omit Commit path, the same way transfer release does.
- `Inventory.AssemblyOrder.PreviewPost` (10076849) applies `postingDate` and `quantityToAssemble` for the preview and restores the order afterwards. The contract in `Inventory Contract Parts ori` (10076919) declares both keys, and the invalid-format error names them. `Inv. Contract Parity Tests ori` (96970) no longer treats this type as parameter-less. `Inventory.AssemblyOrder.Statistics` (10076853) returns the order status in `orderStatus` and keeps `status_` as the same value.
- `Inventory.ItemCharge.Get` (10076875) ignores a quote or blanket order found by SystemId, matching the document-number filter. `Inventory.ItemCharge.Assign` (10076873) refuses a target quantity above the charge quantity that is still assignable.
- `Inventory.Cost.Get` (10076860) keeps an empty `variantCode` as an exact blank-variant filter. An empty `locationFilter` still clears the location filter.
- `Inventory.ItemApplication.Get` (10076867) answers `InvalidParameter` when `itemLedgerEntryNo` is not a JSON integer. Listing applications by `Item Ledger Entry No.` stays as documented: an inbound entry shows the rows recorded on itself.
- `Inventory.Period.Close` (10076877) and `Inventory.Period.Reopen` (10076879) apply the same checks and inventory period entries as platform codeunit `Close Inventory Period` (5820), through `Period Platform Write ori` (10076928). Running 5820 is a nested try function under the message task and cannot insert the entry, so the write stays in the caller transaction. There is no Commit and no StartSession. A close refusal (unadjusted cost, an unadjusted finished order, or open negative inventory) is returned as response text and writes nothing. Closing also closes earlier open periods, reopening also reopens later closed periods, and each changed period gets an inventory period entry. A period that is already in the requested state is left unchanged. `Inv. Period Close Tests` (96979) covers the entry and the idempotent path.
- `Inventory.PhysInventory.Check` (10076884) keeps answering an empty batch as Success with `validationResult` NotReady. Post and PreviewPost still refuse an empty batch. That split is the published contract.
- Contract regressions in `Inventory Contract Batch Tests` (96921) expect the shared `Retryable` entry only when the installed Foundation is 28.0.11 or newer. Release 28.0.10 exposes the enum and does not append the entry.
- `Transfer Order Post Tests` (96914) send `expectedCount` only when the composed contract declares it. Foundation 28.0.10 rejects that key on `Inventory.TransferOrder.Post` and `Inventory.Transfer.UndoShipment` because those types do not declare it.

### Fixed (2026-11-03) - confirmation fixtures on strict Foundation

- Merging main (#185) keeps `Inventory.Transfer.UndoReceipt` (10076911) on the coded MissingParameter and RecordNotFound contract and the Inv. Posting Gate display caption. The translated notes label from that merge uses the same caption.

### Fixed (2026-11-02) - Inventory help and runtime error parity (#152)
- #152: complete remaining Inventory help error codes, attribute examples and subject descriptions; use permission display captions instead of AL names. Preserve published statistics direction and response fields. Strengthen contract guard 96970 across all help chapters and document protected setup administration; improve disabled-domain guidance (10076922). Return coded errors on explicit refusal paths, align error help with MissingParameter/RecordNotFound/PreconditionFailed and native BusinessCentralError, and exercise runtime envelopes in regression tests (96970). Normalize permission captions and Icelandic guidance, including the native journal gate (10076840); keep XLF synchronized.
- Correct Attribute.Create/Update invalid-array help to the existing caught `BusinessCentralError` response (10076919); regress missing, empty and non-array attributes in both languages through the real dispatcher (96900).
- Merge main: keep source-bound tracking (#150/#165) and Foundation confirmation (#176) while preserving the coded refusal help above. Tracking.Assign/Delete help names the Bifrost "Full Access" permission set, and UndoShipment documents the received-line PreconditionFailed.

### Added (2026-11-03) - Inventory setup wizard (#158)

- Five-step Assisted Setup "Set up Bifrost Inventory" (Extensions group): what the app adds, read-only HTTP status with a link to Foundation's setup wizard, access guidance, read-only company domains and explicit completion. Page 10076836, registration codeunit 10076924, management codeunit 10076927 and bilingual tests 96920. Inventory Setup (10076835) gets a Setup Wizard action. The guide never writes HTTP settings, assigns permissions or toggles domains; closing early does not mark completion. Execute permission for the new objects is added to the existing BIFROST Read/Full extensions and to BIFROST InvPost ori (the app's only assignable set, required by the PermissionCoverage guard); the InvPost grant awaits Gunnar's product decision (Architect 1793461090) before merge.

### Fixed (2026-11-03) - receipt undo is not a shipped operation (#150)

- `Inventory.Transfer.UndoReceipt` (codeunit 10076911 `Transf Undo Rcpt Impl ori`) stays disabled. Its overview and notes are translated labels, and the in-repo help plus the posting-permission list no longer present it as a working undo. The released enum value remains. The configured BC symbols still have no `Undo Transfer Receipt` codeunit, so success is not invented.
- Test codeunit 96914 `Transfer Order Post Tests` posts an owned transfer receipt and calls the type in 1033 and 1039. The answer is `PreconditionFailed`, the receipt stays, and no further item ledger entry is posted. Helper 96904 passes that Windows language id through, because a zero language id uses the company default rather than the test's `GlobalLanguage`.

### Fixed (2026-11-03) - Adjust Cost licence and version checks (#182)

- `Inventory.AdjustCost.Run` (codeunit 10076858 `Adjust Cost Run Impl ori`) now calls `AssertIsLicensed` and then `AssertVersion1` after the Costing domain gate and before report 795 runs, like the other Inventory costing types. `Inventory.CostToGL.Post` (10076861) already had both checks on main (#177); this change adds regression coverage for it. Test codeunit 96918 `Inv. Posting Gate Tests` gains an unlicensed-call refusal test for each of the two types.

### Fixed (2026-11-02) - Foundation confirmation and composed contracts (#176)

- Keep the native journal operation selector separate from its posting-confirmation flag (10076840), so the contract-key guard does not mistake internal Calculate/Post/RecordCount selectors for request keys. No guard or allow-list changes.

- Irreversible success examples document `data.expectedCount: 1` for all nine Inventory posting/costing/undo types (10076858, 10076861, 10076866, 10076881, 10076888, 10076909, 10076910 and shared parts 10076919); README explains missing/wrong/matching confirmation and the default single-subject count. `Inventory Native Journal ori` (10076840) accepts this Foundation control only on physical/reclassification/revaluation posting paths, preserving strict preview/check parameter validation.
- Test helpers (96902/96903/96904) supply confirmation only when the deployed Foundation advertises it. Contract regressions (96921) preserve exact raw app metadata and separately verify Foundation's shared `Retryable` entry and confirmation effect; confirmation regressions (96978) exercise missing/wrong/matching counts in 1033/1039 without changing the released Foundation 28.0.3.530 floor.
- Correct Attribute.Create/Update empty-array help to the existing `BusinessCentralError` response in `Inventory Contract Parts ori` (10076919); runtime behavior is unchanged, with malformed-array regressions in 96900 (same scoped correction already published in PR #175).

### Fixed (2026-10-25) - coded Inventory refusals and public help (#148, #155)

- Attribute Create/Update validate the entire request before starting their write process. Missing/invalid entries, unknown attributes/options, conflicting identifiers, blocked items and conflicting or missing mappings return structured, translated refusals. AttributeDefinition.Create returns coded missing/type/duplicate refusals. Runtime and help name the registered Inventory.Attribute types.
- Physical inventory missing batches return RecordNotFound; missing or foreign-batch count lines return InvalidLine before any quantity changes. Other native validation remains BusinessCentralError. Check/Post help includes missing or foreign-batch lineSystemIds, matching the InvalidParameter selection refusal.
- Reclassification and ItemApplication now return coded, localized refusals. ItemApplication.Unapply/Reapply use existing Inventory Write Process 10076842 for native failure rollback and coded response context; Omit Commit still propagates failures to its caller. Reclassification.Post preserves native BC text and adds selected-batch recovery context. Malformed reads use InvalidParameterFormat. Parent #151 strict validation remains intact.
- Attribute, physical inventory and older-type help declares actual codes, remedies and examples. Public help remains English at both LCIDs under Architect disposition 1792832435; tests use the public contract path and separately verify translated runtime refusals and native error parity in 1033/1039. No new objects or permission grants.
- Use the released Foundation 28.0.8.617 public error-context API (Architect 1792830947). Align app/test dependency floors, the dependency probe, AppSource gate and collision restoration with that published release, including exact production/test archive hashes and source provenance. Preserve no-friend, signature-content and compatibility checks; no Foundation source changes.
- Objects: codeunits 10076840, 10076842, 10076844, 10076867–10076869, 10076881–10076885, 10076887–10076889, 10076915, 10076917 and 10076919; tests 96900, 96918, 96921, 96930, 96944 and 96970. No new object IDs or app-version change. Empty Attribute.Get filters retain the Foundation range resolver's RecordNotFound response.

### Fixed (2026-10-25) - transfer posting help (#151)

- Correct the TransferOrder.Post invalid postingType condition in contract help (10076919). ShipReceive remains refused; the description no longer claims it appears in the runtime error text. No posting behavior or accepted values change.

### Fixed

- Cost refusal regression fixture (96937) scopes its Field Access page before editing the user control, verifies that only Last Direct Cost is restricted and restores its row before assertions. This prevents unintended wildcard restrictions and cascading failures; product permission and aggregation behavior is unchanged.

- Issue151 first refusal family: Period.Close/Reopen (10076877/10076879) validate ISO dates before lookup, report missing periods with invariant dates and actionable translated context; AdjustCost.Run process10076859 validates boolean/filter values before running report795 and collects independent format errors. Native bilingual regression codeunit96975. Additional issue151 repairs collect assembly/transfer/attribute-definition/reservation/cost inputs, code assembly undo/transfer posting and cost guards, translate preview summaries, return invariant Reservation.Get statuses and ignore only truly empty physical-posting rows. Journal helper10076840 now raises coded rollback-safe refusals and native line context; tracking helpers10076841/10076925 provide expected values and next actions. New read-process codeunit10076926 preserves coded synchronous Check/Preview failures through rollback isolation, with execute permission only in existing read/write permission extensions. Native journal and tracking failures retain their original BusinessCentralError text with the selected source/batch context and translated recovery fields. Metadata, isolated lookup collection and explicit test fixtures are updated; runtime/independent verification remains tracked at each candidate.

### Fixed (2026-10-31) - transfer posting test confirmation (#150)

- Transfer posting and undo fixtures in codeunit 96914 explicitly confirm their single owned transfer document with `expectedCount: 1`. This keeps the posting, receipt and rollback assertions reachable when Foundation confirmation is enabled; the gate and all existing assertions remain in place.

### Fixed (2026-10-24) - Contract guard declaration identity (#150)

- Ignore permission-set object references when locating AL declarations. This preserves the actual tracking writer header and operation-specific parameter reads regardless of file enumeration order; add source regressions for both orders and a genuine mismatch (`Test-ContractParameterKeys.ps1`; no runtime object or allow-list change).

### Fixed (2026-10-23) - issue #150

- Tracking.Assign/Get/Delete now round-trip native source-bound lot, serial and package tracking. A source line SystemId is required; deletion affects only the selected unreserved entry. Single-entry response fields are retained, native posting remains separate and Omit Commit retains caller transaction ownership.
- UndoShipment explicitly refuses received transfer lines with PreconditionFailed and a return-transfer next step; the selected-shipment repair is inherited from #159.
- Correction to the earlier shipped roster: UndoReceipt is disabled, not a working undo feature. The released enum remains for compatibility only; no native Undo Transfer Receipt codeunit exists in the configured BC symbols. Use a new transfer order for received goods. Historical changelog entries describe earlier releases, not current availability.
- Objects: codeunits 10076897 Tracking Assign Impl ori, 10076899 Tracking Delete Impl ori, 10076900 Tracking Get Impl ori, 10076910 Transfer Undo Shpt Impl ori, 10076911 Transf Undo Rcpt Impl ori; new codeunit 10076925 Inventory Tracking Write ori; permission extension 10076836 BIFROST InvWrite ori; new test codeunit 96974 Inv. Source Tracking Tests ori; test codeunit 96914 Transfer Order Post Tests and explicit fixture codeunit/page 96973. Updated README, contracts and is-IS translations.

### Fixed (2026-10-25) - catalogue quality guard compiles (inventory#152, PR 163)

- Test codeunit 96971 now imports `System.TestLibraries.Utilities` (which resolves `Codeunit "Library Assert"`; `GlobalLanguage` is an AL built-in) and is renamed from the 32-character `Inv. Catalogue Quality Tests ori` to the 28-character `Inv. Catalogue Quality Tests` (AL0305 object-name length limit 30). No behaviour, test, object ID or catalogue text changed; the guard still reads description, selection description and keywords of every Inventory message type in LCID 1033 and 1039.

### Added (2026-10-23) - catalogue quality guard (inventory#152, AC1)

- New test codeunit 96971 `Inv. Catalogue Quality Tests` (test range 96900-96999; 28 characters, within the 30-character AL0305 object-name limit): for every Inventory message type it reads the catalogue `description`, `selection description` and `keywords` through the `Msg Interface ori` / `Msg Discovery ori` interfaces in LCID 1033 and 1039 and fails on a text that is empty at either language or identical in both languages, i.e. a missing `is-IS=` target, an empty target or a `Locked` (non-translatable) catalogue label. This is the guard required by issue #152 AC1; the catalogue texts themselves are already present on main (958/958 in `app/Translations/Bifrost Inventory.is-IS.xlf`, verified live by Claude at PR 160).

### Fixed (2026-10-29) - registration under restricted licence administration (#173)

- `Inventory Registration ori` (codeunit 10076845) declares `InherentPermissions = X` and `InherentEntitlements = X`, so its `OnRegisterApps` subscriber can run when a restricted licence administrator opens Bifröst Setup. No permission set is widened.
- `Inv. Registration Tests ori` (codeunit 96972) opens Foundation's actual Setup page under `BIFROST LicAdm ori` plus the test-only `Inv Setup Test` baseline (96972). The baseline includes Microsoft's `D365 Basic - Read` platform baseline, Foundation Read and the execute-only `All Objects` test role for the complete internal Setup dependencies at the supported 28.0.3.530 floor, then excludes the Execute grant on `Inventory Registration ori` through `Inv Reg Excl Test` (96973). This preserves the inherent-Execute regression without granting general administration: direct Setup writes are denied, the page remains non-editable and the licence-administrator action is visible. No tenant permission role or user assignment is created. The test does not invoke Sync or write licence, EULA or trial state.

### Fixed (2026-10-25) - domain usage review corrections (#147)

- `Inventory Setup ori` (table 10076836) checks for a nonblank ledger location before loading the per-item location comparison. A blank-only ledger leaves Reclassification off without fetching every row into AL; mixed blank/nonblank locations still participate in the unchanged mapping. `Inventory Domain Usage Tests` (96963) covers both cases, including a 1000-entry bounded-read regression and actual setup-page creation.
- `Inventory Setup ori` (table 10076836) stops at the first matching usage signal. Reclassification reads the item ledger only when Location, Bin Content and Warehouse Entry supply no signal; the other multi-signal checks also return early. The domain mapping is unchanged.
- `Inventory Install ori` (codeunit 10076835) registers the domain-usage upgrade tag for newly created companies, preserving later administrator opt-outs on the next upgrade. `Inventory Domain Usage Tests` (96963) covers new-company tag registration, preserved opt-outs, bounded reads with an existing Location and the per-item ledger-location fallback.

### Fixed (2026-10-23) - company domain defaults from usage (#147)

- `Inventory Setup ori` table 10076836 derives new-row defaults from native company data. `Inventory Upgrade ori` (10076836) runs the same off-to-on evaluation once per company under its own upgrade tag; `Inventory Install ori` (10076835) applies it on fresh installs. Enabled domains and absent rows are preserved, and unchanged rows are not modified. No licence, consent or HTTP setting is written.
- Usage mapping: attributes → Item Attribute; transfer → in-transit Location/Transfer Header/Transfer Route; assembly → BOM Component/Assembly Header/Production BOM Header; reservations → Reservation-status entries; tracking → tracking codes, tracked Items or lot/serial/package entries; physical inventory → recording headers, physical ledger or counting-period Items; costing → Value Entry/order adjustment; reclassification → locations, bins, warehouse entries or multiple ledger locations per Item; application → Item Application Entry; periods → Inventory Period; prices → Item Price List Lines; references → Item Reference; availability → Items/ledger entries (valid demand/supply refers to Items); charges → Item Charge; categories → Item Category/categorized Items. README documents the mapping and the existing Foundation discovery boundary for disabled types.
- Native regressions in `Inventory Domain Usage Tests` (96963) cover all fifteen domains with and without data, the actual setup page/insert trigger, upgrade tagging, existing enabled switches, missing setup, idempotence and distinguishing transfer/reservation signals. The test app adds Microsoft's System Application Test Library for supported upgrade-tag fixture cleanup. `.claude/CLAUDE.md` no longer describes the superseded opt-in default.

### Fixed (2026-10-29) - Reclassification test allocation after main integration (#159, PR #164)

- Move `Reclass Check Perm Tests ori` from codeunit 96972 to 96976 and `Reclass Preview Tests ori` from 96971 to 96977. This avoids registration test 96972 introduced by #174 and preserves the allocations already used by open PRs #165 (96974), #166 (96975) and #172 (96971). Test assertions and production behavior are unchanged; all suites remain included.

### Fixed (2026-10-24) - Native reclassification preview and reservation consistency (#159, partial)

- Test-only fixture codeunit/page 96973 supports the isolated owned `CRONUS W8 Inv164` company with a separate `R8` record prefix, preserving existing `W8` fixtures during exact-tip re-verification after the main merge. Existing fixture and company guards remain.

- Correct the cross-reference in Reclassification.Post notes to describe PreviewPost as native posting simulation with captured entries and rollback (10076888; PR #164 F1).

- `Inventory.Reclassification.PreviewPost` now runs native posting preview, validates an existing nonempty Transfer batch, returns captured ledger entries and rolls back simulated posting changes. Existing `lines`, `lineCount` and `rollback` fields remain. The posting gate is intentional for native simulation. `Inventory.Reclassification.Check` now requires only journal read permission (codeunits 10076887, 10076889; execute grants in 10076835/10076836; tests 96971, 96972 and permission set 96971).

- `Inventory.Reservation.Create` shares sales item/line eligibility with AutoReserve: Reserve Never, drop shipment, special order and missing shipment date are refused. `Reservation.Cancel` checks both sides for Reservation status, matching item/variant/location and opposite base quantities, then rechecks under lock before native cancellation (10076893, 10076896, 10076892, 10076842; test 96946). Test-only codeunit 96973 explicitly seeds owned preview/stock fixtures for MCP; it is never invoked on install.

### Fixed (2026-10-23) - Inventory posting guards and chained writes (#159, partial)

- Preserve Gunnar's AC2 decision: a failed `Inventory.AssemblyOrder.Post` keeps the requested `Quantity to Assemble` written before the isolated native post, as the existing bilingual help states. English/Icelandic dispatcher regressions fail after real native output writes and verify that the requested quantity survives while posted headers and item entries roll back (tests 96909, 96938; production codeunit 10076855 unchanged).
- `Inventory.CostToGL.Post` initializes native per-entry posting with Post=true, applies item and document filters to pending value entries, accepts the mandatory G/L journal template/batch, and returns actual posted/remaining counts. It uses the existing isolated write process and the documented independent Post commit boundary. Native regressions verify real G/L entries and selected/unselected value-entry amounts (10076861, 10076842; test 96944).
- `Inventory.Reclassification.Post` refuses missing templates and non-Transfer template types before any line is posted, with coded English/Icelandic recovery instructions. Help reflects the enforced template boundary (codeunit 10076888).
- `Inventory.Assembly.UndoPost` and `Inventory.Transfer.UndoShipment` require the inventory posting token in addition to their existing document-write and company-domain gates, because undo creates reversing entries (codeunits 10076909, 10076910).
- `Inventory.Cost.Update`, `Inventory.ItemCategory.Set` and `Inventory.ItemCharge.Assign` honor `Omit Commit`: chained calls run without a Boolean Codeunit.Run boundary so failures propagate and caller writes roll back together. Standalone calls retain their existing isolated error handling (codeunits 10076863, 10076871, 10076873).
- Undo now runs atomically: Assembly undo suppresses native commits inside the existing write process; transfer undo passes the complete document-filtered set once to the native undo, preserving selection and rolling back all lines on failure. Native tests inject a failure after real undo writes and prove ledger/header rollback plus another shipment remaining unchanged (10076842, 10076909, 10076910; tests 96909, 96914, 96938). This also addresses the shared wrong-shipment finding in #150; its tracking and receipt-undo acceptance remains pending.
- Restore explicit execute grants for the costing, application and undo implementation codeunits named in #159; read operations are granted to Read and Full, writes only to Full. Native table rights and the separate posting token remain required. Restricted tests execute the domain refusals through the actual shipping Full role and the undo tests no longer supply test-only implementation grants (permission extensions 10076835, 10076836).
- Tests cover non-Transfer templates in both languages, actual restricted caller grants/denials, native subscriber rollback of an uncommitted caller write, and category/charge mutation suites in chained mode (96918, 96919, 96920, 96937, 96944 and existing category/charge tests). This phase does not close #159; real reclassification preview/read permission, reservation consistency and remaining live verification are still pending. Gunnar's AC2 decision retains existing pre-post assembly quantity persistence.

### Changed (2026-10-22) - message type contract and discovery up to Foundation parity

- All 59 Inventory message types now declare the chapters Foundation's own types declare: envelope, target, parameters (with `children` on every array of objects), response (with `children` on arrays), errors with a machine code (or the error text) and a fix, effect with `effect` (read, write or irreversible), `changes`, `idempotent` and `permissionSet`, related, workflow for every type that is not a plain read, examples with a request and a response, overview and notes. Texts were rewritten from the implementation; where the help contradicted the code it was corrected (error codes, response fields, parameter types, commit behaviour of the Post types). `Inventory.Cost.Get` declared the effect `readOnly`, now `read`; `Inventory.CostToGL.Test` named an error code and chapter shapes that no caller could get, now standard.
- No message type, public procedure, object ID, enum value, field or runtime behaviour changed, and no direction was narrowed or widened. `ExecuteBifrostTask` and all helpers are untouched. Labels whose English text changed carry updated `is-IS=` comments; `app/Translations/Bifrost Inventory.is-IS.xlf` is regenerated with `tools/Update-IcelandicXlf.ps1` and passes `tools/Test-IcelandicXlfInSync.ps1`.
- No root `strict` option in the envelopes: the Foundation floor is 28.0.3.530 and the option was added to Foundation later (core#923, 06.10.2026).
- Existing tests that pin the absence of a chapter were not changed, so these chapters stay absent: workflow of `Inventory.AdjustCost.Run`, `Inventory.CostToGL.Post`, `Inventory.Attribute.Create/Update` and `Inventory.AttributeDefinition.Create`; notes of `Inventory.Attribute.Get`, `Inventory.AttributeDefinition.Create` and `Inventory.CostToGL.Test`; examples of `Inventory.Attribute.Create/Update`; target of `Inventory.AttributeDefinition.Create`.
- Objects changed (contract and discovery text only, no runtime change): codeunits 10076849 `Asm. Doc Prev. Post Impl ori`, 10076850 `Asm. Order RefreshLn Impl ori`, 10076851 `Asm. Order Release Impl ori`, 10076853 `Asm. Order Statistics Impl ori`, 10076855 `Assembly Order Post Impl ori`, 10076856 `Assembly Order Reopen Impl ori`, 10076857 `Avail. By Period Impl ori`, 10076858 `Adjust Cost Run Impl ori`, 10076860 `Cost Get Impl ori`, 10076861 `Cost To GL Post Impl ori`, 10076862 `Cost To GL Test Impl ori`, 10076863 `Cost Update Impl ori`, 10076864 `Reval Preview Impl ori`, 10076865 `Revaluation Calc Impl ori`, 10076866 `Revaluation Post Impl ori`, 10076867 `Item Appl. Get Impl ori`, 10076868 `Item Appl. Reapply Impl ori`, 10076869 `Item Appl. Unapply Impl ori`, 10076870 `Item Category Get Impl ori`, 10076871 `Item Category Set Impl ori`, 10076873 `Item Charge Assign Impl ori`, 10076875 `Item Charge Get Impl ori`, 10076876 `Item Ref. Resolve Impl ori`, 10076877 `Period Close Impl ori`, 10076878 `Period Get Impl ori`, 10076879 `Period Reopen Impl ori`, 10076881 `Phys. Invt. Post Impl ori`, 10076882 `Phys. Invt. Record Impl ori`, 10076883 `Phys. Inv. Calc Impl ori`, 10076884 `Phys. Inv. Check Impl ori`, 10076885 `Phys. Inv. Preview Impl ori`, 10076886 `Price Update Impl ori`, 10076887 `Reclass Check Impl ori`, 10076888 `Reclass Post Impl ori`, 10076889 `Reclass Preview Impl ori`, 10076890 `Order Tracking Get Impl ori`, 10076892 `Reservation Cancel Impl ori`, 10076893 `Reservation Create Impl ori`, 10076894 `Reservation Get Impl ori`, 10076895 `Reserv. AutoReserve Impl ori`, 10076897 `Tracking Assign Impl ori`, 10076898 `Tracking Avail. Get Impl ori`, 10076899 `Tracking Delete Impl ori`, 10076900 `Tracking Get Impl ori`, 10076901 `Transf Doc Prev. Post Impl ori`, 10076903 `Transfer Order Post Impl ori`, 10076904 `Transfer Order Reopen Impl ori`, 10076905 `Transfer Order Stats Impl ori`, 10076907 `Transf. Order Release Impl ori`, 10076909 `Assembly Undo Post Impl ori`, 10076910 `Transfer Undo Shpt Impl ori`, 10076911 `Transf Undo Rcpt Impl ori`, 10076919 `Inventory Contract Parts ori`. Test app: 96902 `Inventory Test Library ori`, 96970 `Inv. Contract Parity Tests ori` (96970 is new).
- Tests: new `Inv. Contract Parity Tests ori` (96970) walks every Inventory type and fails on a missing chapter, an error without a code or text, a direction that does not match the effect, discovery texts that are empty or not translated at 1039, an example that is not a request of its own type, and AL object names in notes or overview. `Inventory Test Library ori` accepts `number` as a response schema type.

### Fixed (2026-10-21) - Pipeline: AppSource build gate after the first AppSource release

- Pipeline: the AppSource build gate no longer fails after the first AppSource release (previous self-app removed from the compile symbol cache; AppSourceCop baseline kept). New `tools/prune_self_symbols.py`, called from `tools/Assert-AppSourceBuild.ps1` before the gate; regression tests in `tools/tests/test_foundation_restore.py`. Port of attachments#174.
### Changed (2026-10-21) - AppSource delivery

- `.AL-Go/settings.json`: `deliverToAppSource` names the Partner Center offer for Bifrost Inventory (productId abaae78a-1f83-40fe-b345-b34634b8724b, main app folder `app`, branch main, no continuous delivery), so the Publish To AppSource workflow can deliver new versions to the offer.
## [28.3.0.0] - 2026-10-20 (first AppSource version)

### Changed (2026-10-20) - version 28.3.0.0 for the first AppSource release

- `app/app.json` and `test/app.json` (including the test app's dependency on Bifrost Inventory) go from 28.1.0.0 to **28.3.0.0**, matching the app's Business Central application minimum, 28.3 (Gunnar, 20.10.2026).

### Changed (2026-10-20) - object IDs moved to 10076835–10077034

- Every app object now uses the single range 10076835–10077034; `app.json` drops 10036885–10036934 and 70013400–70013499. Names, behaviour and the test range 96900–96999 are unchanged. README lists the new IDs.
- Message type enum values follow: each value is the ID of its implementation codeunit (for example `Inventory.Cost.Get` 10076860 on `Cost Get Impl ori`). `Inventory.PhysInventory.Record` takes the ID of `Phys. Invt. Record Impl ori` (10076882); `Inventory.PhysInventory.RecordCount`, which shares that codeunit, is 10076924.
- Earlier entries below keep the IDs that were valid when they were written.
- An installation from an earlier build stores the old enum values: uninstall it with its data before publishing this build.

### Fixed (2026-10-20) - test ordinals after the range move

- Inventory Contract Batch Tests (96921) no longer hard-code the Message Type ordinals of the four Inventory.Attribute types; they read them from the named enum values, so the Test build passes after the move to 10076835–10077034 and a later renumber cannot break them.

### Fixed (2026-10-19) - contract parameter keys, mixed-language refusals and Icelandic xlf parity in CI (#97, #30, #32, #33)

- Contract parameters (#97, #30): `tools/Test-ContractParameterKeys.ps1` now passes the full scan with an empty allow-list. On main 9f0188f it reported 11 problems under pwsh 7. The 7 extra findings seen under Windows PowerShell 5.1 (`malformed-contract-json` and the read-not-declared keys of `Inventory.AdjustCost.Run` and `Inventory.CostToGL.Post`) come from its missing `ConvertFrom-Json -NoEnumerate`; those contracts were valid.
  - `Inventory.CostToGL.Test` no longer declares `postingDateFilter`, which it never read; `itemNoFilter` gets a description.
  - `Inventory.Transfer.UndoShipment` declares its required `documentNo`.
  - `Inventory.Reclassification.Check` declares the `journalTemplateName` / `journalBatchName` aliases it reads. `templateName` and `batchName` are optional in the contract, because either name of each pair is accepted.
  - `Inventory.PhysInventory.Calculate`, `RecordCount` and `Record` no longer reach the `lineSystemIds` line selection, which only `Check`, `PreviewPost` and `Post` accept (Calculate and RecordCount already refused the key). No behaviour change.
  - `Inventory.Tracking.Get` in item mode now answers `MissingParameter` on `itemNo` when the request has no source, no subject and no item selector, or only a blank `itemNo`. Before, Foundation's item range had no filter and the first item in the company was read. The check is the one `Inventory.TrackingAvailability.Get` uses (#128), now shared as `HasItemSelection` in `Inventory Tracking Read ori`.
- Mixed-language refusals (#33): the refusals of Assembly.UndoPost, ItemApplication.Get/Reapply/Unapply, Period.Close/Reopen, Reclassification.Check/PreviewPost/Post, Reservation.Create/Cancel (expected values), Tracking.Assign/Delete, TransferOrder.Create/Post/PreviewPost and Transfer.UndoShipment/UndoReceipt are translated labels instead of Locked labels or string literals. The English text is unchanged. `tools/Test-MixedLanguageLabels.ps1` passes with an empty allow-list (main: 19 procedures and 28 Locked refusal labels).
- Source Guards runs the full ContractParameterKeys and MixedLanguageLabels scans, with their self-tests and python regression tests, and the IcelandicXlfInSync self-test.
- Icelandic xlf parity (#32): `.AL-Go/PostCompileApp.ps1` runs `tools/Test-IcelandicXlfInSync.ps1` on the g.xlf of the final app compile, so Pull Request Build and CI/CD fail when the committed `is-IS.xlf` is not what `tools/Update-IcelandicXlf.ps1` generates. `app/Translations/Bifrost Inventory.is-IS.xlf` is regenerated; main was in sync before this change.
- Help links (#31) stay unwired. The app side is in place (`contextSensitiveHelpUrl`, slug `inventory-setup` on `Inventory Setup ori`) and `tools/Test-HelpLinks.ps1` passes against the help pages of businesscentralal/bifrost#108, which is not merged yet.
- Tests: Inventory Tracking Read Tests (96927) adds `Scenario_AC3_NoItemSelectionIsRefused` and `Scenario_AC3_BlankItemNoIsRefused`.

### Added (2026-10-19) - costing, item tracking reads and physical inventory (#4, #5, #6)

- Costing (#4): `Inventory.Cost.Update` changes Unit Cost, Last Direct Cost or Standard Cost on one item card through native validation and refuses Standard-costed items with a pointer to `Inventory.Revaluation.Post`. `Inventory.Revaluation.PreviewPost` and `Inventory.Revaluation.Post` preview and post a Revaluation journal batch with Item Jnl.-Post Batch. `Inventory.Cost.Get` returns a native cost snapshot and `Inventory.Price.Update` writes Unit Price through native validation. Data.Records.Set refuses the Item cost and price fields and names the dedicated type.
- Cost.Get keeps #140's single-item contract (data.itemNo or subject, MissingParameter, ConflictingIdentifiers, RecordNotFound, calculated inventory) and also accepts a SystemId subject, SystemId keys or a tableView; one selected item answers its fields at the top level as well as in `items`. TrackingAvailability.Get keeps #128's MissingParameter on a missing itemNo.
- Item tracking (#5): `Inventory.Tracking.Get` reads the lot, serial and package tracking of a document line or the open item ledger entries of an item; `Inventory.TrackingAvailability.Get` groups availability with native expiration dates (blank unless the item tracking code uses expiration dates) and paging.
- Physical inventory (#6): `Inventory.PhysInventory.Calculate` runs report 790 into an empty batch and requires `postingDate` and `documentNo` (`itemNo`, `locationCode`, `variantCode` filter the items). `RecordCount` records several counts (an omitted `qtyCounted` leaves the line uncounted, 0 records zero), `Check` reports readiness, `PreviewPost` previews, and `Post` returns the item register and both ledger entry ranges. Item Journal Line stays writable through Data.Records.Set.
- New objects: codeunits 70013406 `Revaluation Post Impl ori`, 70013407 `Reval Preview Impl ori`, 70013408 `Cost Update Impl ori`, 70013409 `Inventory Native Journal ori`, 70013410 `Inventory Tracking Read ori`, 70013411 `Tracking Get Impl ori`, 70013412 `Inventory Write Process ori`, 70013432 `Inventory Cost Read ori`, 70013437 `Inventory Cost Data Guard ori`, 70013438 `Inventory Card Write ori`, 70013479 `Phys. Inv. Check Impl ori`; message type values 70013437 `Inventory.Cost.Update`, 70013438 `Inventory.Revaluation.Post`, 70013413 `Inventory.Revaluation.PreviewPost`, 70013414-70013416 `Inventory.PhysInventory.Check/PreviewPost/RecordCount`, 70013417 `Inventory.Tracking.Get`. Execute grants go to the `BIFROST InvRead ori` / `BIFROST InvWrite ori` permission set extensions; the attribute permission sets are unchanged.
- Tests: codeunits 96927, 96933, 96936-96946 and permission sets 96934-96936.

### Fixed (2026-10-19) - message types that always failed (#122, #123, #124, #125)

- `Inventory.TransferOrder.Post` with `postingType` Receive no longer answers "The Transfer Header does not exist" after a receive that completes the order: the posting runs in batch mode (no "posted and deleted" message) and the posted shipment, receipt or direct transfer number is captured from the posting events. The response adds `orderDeleted`.
- `Inventory.PhysInventory.Calculate` takes the required `postingDate`, and `Inventory.PhysInventory.Post` posts the positioned batch; an empty batch is `PreconditionFailed` with the batch name as `received` and "at least one journal line" as `expected`.
- `Inventory.Reservation.Create` reserves against a real source line (`sourceType` 37/39/5741/901, `sourceSubtype`, `sourceNo`, `sourceLineNo`, `quantity`) and returns `entryNo`/`entryNos`; nothing available is `PreconditionFailed`. `Inventory.Reservation.Cancel` cancels the pair through Reservation Engine Mgt. Both write through `Inventory Write Process ori` so a native error rolls the write back.

### Added (2026-10-19) - item reference, availability by period, item charge, item category, auto-reserve and order tracking types (#101, #103, #108, #111, #112)

- `Inventory.ItemReference.Resolve` (Item Ref. Resolve Impl ori, 10036917) resolves `referenceNo` or `references[]` with optional `referenceType` (barCode, customer, vendor, blank), `referenceTypeNo` and `date` to item, description, variant, unit of measure, reference type and the matched reference row. When no reference matches it checks the item number and then the item GTIN and says which `source` matched. No match answers `RecordNotFound`, several items `AmbiguousRecord`, `referenceTypeNo` with a barcode or blank type `InvalidParameter`. An ended reference is ignored; a blocked item answers `blocked: true`.
- `Inventory.AvailabilityByPeriod.Get` (Avail. By Period Impl ori, 10036918) reads projected availability per day, week, month, quarter or year for `itemNo` or up to 20 `items`, with optional `variant`, `location` and `amountType` (`netChange`, default, or `balanceAtDate`), from `from` for `periods` (1-53) periods. Each row has periodStart, periodEnd, grossRequirement, scheduledReceipt, plannedOrderReceipt, projectedAvailableBalance, inventory and amountType, calculated as Item Availability by Periods does. Above the limits answers `LimitExceeded`; a service or non-inventory item `PreconditionFailed`.
- `Inventory.ItemCharge.Assign` (Item Charge Assign Impl ori, 10036919, with write step Item Charge Assign Proc ori, 10036927) assigns a Charge (Item) line on a purchase or sales document by `method` (equally, byAmount, byWeight, byVolume) through the standard suggest logic, or to explicit `targets[]` (order, invoice, return and credit memo lines, posted receipt, shipment, transfer receipt, return shipment and return receipt lines) with `qtyToAssign`. A new assignment replaces the earlier rows and answers `replacedCount`. `Inventory.ItemCharge.Get` (Item Charge Get Impl ori, 10036920) answers the assignment rows and `unassignedQuantity`. Item Charge Restrict ori (10036921) blocks `Data.Records.Set` on both Item Charge Assignment tables and points to the new types.
- `Inventory.ItemCategory.Get` (Item Category Get Impl ori, 10036922) reads categories with code, description, parentCategory, indentation, presentationOrder and, with `includeAttributes`, the category attributes with id, name, type, value and `inherited`. `Inventory.ItemCategory.Set` (Item Category Set Impl ori, 10036923, write step Item Category Set Proc ori, 70013499) creates or updates a category and its default attribute values through the same validation as the Item Categories page. A loop answers `InvalidParameter`, an unknown attribute or value `RecordNotFound`, re-parenting or delete `PreconditionFailed`. Items already in the category keep their own values. Item Category Restrict ori (10036924) blocks `Data.Records.Set` on Item Category and Item Attribute Value Mapping and points to the dedicated types.
- `Inventory.Reservation.AutoReserve` (Reserv. AutoReserve Impl ori, 10036925, write step Reserv. AutoReserve Proc ori, 70013439) runs Auto Reserve on a sales order line (document keys or `systemId`, optional `quantity`) and answers reserved, reservedQuantity, outstandingQuantity, fullyReserved and the entries it made. A partial reservation is rolled back and answers `LinesSkipped`; Reserve = Never or a line that cannot be reserved answers `PreconditionFailed`; an already reserved line answers `reserved: 0, fullyReserved: true`. `Inventory.OrderTracking.Get` (Order Tracking Get Impl ori, 10036926) reads the order tracking chain for a sales, purchase, transfer (with `direction`), assembly line or an item ledger entry without writing. Order Tracking Transfer ori (10036929) supplies the transfer line source that the base app does not provide.
- New domains on Inventory Setup: `ItemReference` (field 21), `Availability` (22), `ItemCharge` (23) and `ItemCategory` (24). A new company gets them on. They are not switched on by upgrade: a company that already has an Inventory Setup row turns them on from the Inventory Setup page. AutoReserve and OrderTracking use the existing Reservations domain.
- Permissions: BIFROST InvRead ori executes the read-only types and BIFROST InvWrite ori executes all of them. No standard-table grants are added and the attribute permission sets are unchanged; callers need Business Central permissions on the tables involved. IsEnabled and Execute check them and answer `PermissionDenied` with a nextStep naming the sets.
- Every user-facing text is a translated label; `app/Translations/Bifrost Inventory.is-IS.xlf` is regenerated.
- Tests: Item Ref. Resolve Tests/Perm (96950/96951), Avail. By Period Tests/Perm (96952/96953), Item Charge Tests/Perm (96954/96955), Item Category Tests/Perm (96956/96957), Reserv. AutoReserve Tests/Perm (96958/96959) and Order Tracking Get Tests (96962). Inventory Contract Batch Tests (96921) now expects 52 types registered by this app and 43 in the LCID 1033/1039 census.
### Changed (2026-10-19) - document lookup errors chapters list InvalidParameterFormat and MultipleErrors (#27, #26)

- Inventory Contract Parts ori (70013445) gives the eleven TransferOrder and AssemblyOrder types that look up a document through Foundation's `Document Lookup ori` (Release, Reopen, Post, PreviewPost, Statistics; Assembly also RefreshLines) an `InvalidParameterFormat` entry that names `data` and the identifier keys (`documentNo`, `transferOrderNo` or `assemblyOrderNo`, `no`, `systemId`, `recordSystemId`, `id`) and exactly one `MultipleErrors` entry. The old "A SystemId or document identifier cannot be read." wording is gone for these types. The Create types and the Item attribute types keep their chapters (#27).
- Inv. Lookup Contract Tests (96922) asserts those chapters, that the Create and Item types list no `MultipleErrors`, and that the chapters stay English when the caller's language is Icelandic. Inv. Lookup Format Tests (96923) asserts the runtime answers of TransferOrder.Statistics and AssemblyOrder.Statistics for `data` as an array or invalid JSON, `documentNo` as an object, `null`, number, array or boolean, `systemId` as `null`, two wrong keys (`MultipleErrors`, `systemId` before `documentNo`), an empty `documentNo` (`MissingParameter`), and a valid subject with a wrong key (no `totals`) (#27).
- Translated with is-IS labels, salvaged from the worker-8 branch: the Item attribute refusals in Item Attribute Resolve ori (10036908), Item Attr. Create Process ori (10036905) and Item Attr. Update Process ori (10036906), the journal refusals of Phys. Invt. Calc Impl ori (70013464), and the TransferOrder, AssemblyOrder and attribute overview and notes texts in Inventory Contract Parts ori (70013445). English text is unchanged. Its Period.Close and Period.Reopen changes are dropped; #126 already made their catalogue text translatable.
- `docs/contracts.md` lists the eleven transfer and assembly lookups only; undo and reservation types do not use the Foundation lookup.
- The runtime answers in 96923 need Foundation core#711 (28.0.2 or later); the 28.0.3.530 floor set by #142 covers it, so this change does not touch `app.json`. #26: no call to a removed Dispatcher or Message Argument helper remains in `app/` or `test/`, and both apps compile with 0 errors and 0 warnings (CodeCop, UICop and AppSourceCop on both apps).

### Fixed (2026-10-19) - inventory reads, coded refusals and remaining Icelandic text (#126, #127, #128, #129)

- `Inventory.Cost.Get` returned `inventory` 0 for an item with stock, and `Inventory.Revaluation.Calculate` returned `inventoryValue` 0 next to the correct `remainingQuantity`. Both read FlowFields that were never calculated. Cost Get Impl ori (70013468) now calculates `Item.Inventory`; Revaluation Calc Impl ori (70013488) calculates `Cost Amount (Actual)` and `Cost Amount (Expected)` on each open item ledger entry, adds remaining quantity × (actual + expected) / quantity, and skips entries with quantity 0 instead of dividing by zero. When the value entries really are 0, the value stays 0; it is not estimated from the unit cost (#127).
- A missing or blank `data.itemNo` on `Inventory.Cost.Get` and `Inventory.TrackingAvailability.Get` now returns `MissingParameter` with `parameter`, `expected` and `nextStep` instead of the legacy text-only refusal. Revaluation Calc Impl ori (70013488) answers a missing item with `MissingParameter` and an unknown item with `RecordNotFound`, the codes its errors chapter already declared (#128).
- `Inventory.Reservation.Get` and `Inventory.Cost.Get` use the message subject as the item number when `data.itemNo` is omitted. A subject and `data.itemNo` that name different items return `ConflictingIdentifiers`; a non-value `data.itemNo` returns `InvalidParameterFormat`; an unknown item on Cost.Get returns `RecordNotFound`. Without either value, Reservation.Get still returns every entry and Cost.Get returns `MissingParameter`. The resolver and its error entries live in Inventory Contract Parts ori (70013445) (`TryResolveItemNo`, `AddItemNoSubjectErrors`); Reservation Get Impl ori (70013477) and Cost Get Impl ori (70013468) use them (#129).
- The description, keyword list and selection description of the nine types that were still English at LCID 1039 are labels with is-IS translations: `Inventory.AdjustCost.Run` (70013460), `Inventory.CostToGL.Post` (70013462), `Inventory.Period.Close` (70013485), `Inventory.Period.Reopen` (70013484), `Inventory.Tracking.Assign` (70013470), `Inventory.Tracking.Delete` (70013471), `Inventory.Transfer.UndoShipment` (70013480), `Inventory.Assembly.UndoPost` (70013482) and `Inventory.Reclassification.Post` (70013493). English text is unchanged (#126).
- The domain-off `nextStep` in Inventory Domain Gate ori (70013453) and the refusals that stayed English at LCID 1039 are translated and coded: AssemblyOrder.Create missing item and quantity (`MissingParameter`, 70013424, including the field write restriction text), Revaluation.Calculate unknown item (`RecordNotFound`) and PhysInventory.Record unknown line (`InvalidParameter` on `lineNo`, 70013466) (#126).
- Every new refusal, errors-chapter, overview, notes and parameter-description text is a label with an is-IS comment; `app/Translations/Bifrost Inventory.is-IS.xlf` is regenerated with `tools/Update-IcelandicXlf.ps1`.
- Tests: Inventory Contract Batch Tests (96921) checks the nine catalogue entries in LCIDs 1033 and 1039. New Inventory Item Refusal Tests (96930) cover the coded refusals in 1033 and 1039, Inventory Item Subject Tests (96931) the subject resolution and conflict, and Inventory Item Quantity Tests (96932) calculated inventory and remaining value. Assembly Order Test Helper (96903) passes the session language to the dispatcher, because language id 0 resets to the company default. These codeunits were drafted as 96922–96924 on the worker branches; those IDs stay reserved for #27.
- Inventory Contract Batch Tests (96921) no longer requires exactly four `Inventory.ItemJournal.*` types: Foundation owns them and its current build registers five, which failed `AllInventoryTypes_RelatedNamesExist`. The four known types must still be present, and the 44 types of this app are still counted exactly.

### Fixed (2026-10-17) - cost reads calculate inventory quantity and value

- `Inventory.Cost.Get` calculates the Item Inventory flow field before it returns `inventory`. `Inventory.Revaluation.Calculate` calculates `Cost Amount (Actual)` and `Cost Amount (Expected)` before remaining inventory value, so an open quantity is no longer reported with value 0. Cost Get Impl ori (70013468) and Revaluation Calc Impl ori (70013488). Inventory Item Quantity Tests (96924) posts its own stock and checks the quantity and value (#127).

### Changed (2026-10-19) - AppSource preparation

- The app and the test app now require Bifrost Foundation **28.0.3.530** (was 28.0.1.0) and `application` **28.3.0.0** (was 28.0.0.0). Both compile against the Foundation 28.0.3 release package with CodeCop, UICop and AppSourceCop at 0 errors and 0 warnings. CI probes that release (`release_status: release`, `version: 28.0.3`) instead of the latest build.
- `app.json`: brief and description cover the whole app; help, privacy statement and EULA point at docs.bifrost.origo.is; `contextSensitiveHelpUrl` is `https://docs.bifrost.origo.is/{0}/help/inventory/`. The obsolete `NoImplicitWith` feature is removed.
- Inventory Setup (page 70013452) sets `ContextSensitiveHelpPage = 'inventory-setup'`. The help page is added to the documentation site separately.
- `BIFROST InvPost ori` (70013444) stays assignable: it is the only grant of the posting gate and of the Inventory Setup page. AGENTS.md and `.claude/CLAUDE.md` no longer say the app has no assignable permission set, and no longer say that cost and price message types are out of scope.
- The build runs CodeCop and UICop on the app and the test app, AppSourceCop on the test app, and fails on warnings. The test app gets `test/AppSourceCop.json` and suppresses the AppSource-only manifest rules AS0015, AS0051, AS0054, AS0084 and AS0092, as in the sibling apps.
- The AppSource build gate from Bifrost Attachments (`tools/Assert-AppSourceBuild.ps1`, `tools/appsource_gate.py`, `tools/stage_foundation_inputs.py`, the `.AL-Go` compile hooks and the Pipeline stage in `_BuildALGoProject.yaml`) runs in every build; see `tools/AppSourceBuildGate.md`. The Signed stage stays deferred.
- Source Guards add unique object/enum value IDs (`tools/Test-UniqueObjectIds.ps1`), build inputs (`tools/check_build_inputs.py`: allocations and the Foundation floor) and the compiler symbol-alias gate.
- README follows the Origo template. The AppSource listing moves from branch `appsource/listing` to `app/docs/appsource/` and now covers the whole app, with a release checklist and the market list. The product sheet and three more screenshots still need to be made.

### Fixed (2026-10-16) - integrate contract tooling after product acceptance

- Reconcile the existing contract and mixed-language guard repairs with merged PR96 on main. Preserve its product, test and translation files unchanged; retain request-lineage, payload-generation, branch-parser and label-property regression coverage (#30–33). Production guard wiring and whole-issue acceptance remain pending. No AL object IDs, app versions, permissions or workflows change relative to main.

### Fixed (2026-10-16) - runtime catalogue localization

- Replace literal catalogue descriptions with translatable labels for the 35 scoped message types, including TransferOrder.Release. Convert the remaining 17 literal keyword lists and 17 selection descriptions; preserve all existing English text and existing translated labels. Regenerate `app/Translations/Bifrost Inventory.is-IS.xlf` from the compiler output.
- Remove compiler/developer instructions from public Reservation.Create and CostToGL.Test notes and clear reused notes outputs. Message execution and wire identifiers are unchanged.
- `InventoryContractBatchTests.Codeunit.al` (96921) adds a language-switch regression over all 35 scoped catalogue entries in LCIDs 1033/1039 and checks both removed notes outputs. The existing nonempty discovery check alone did not detect English literals at LCID 1039.
- Amended implementation files and codeunit IDs: `ReclassCheckImpl.Codeunit.al` (70013475); `AsmDocPrevPostImpl.Codeunit.al` (70013423); `AsmOrderRefreshLnImpl.Codeunit.al` (70013421); `AsmOrderReleaseImpl.Codeunit.al` (70013426); `AsmOrderStatisticsImpl.Codeunit.al` (70013422); `AssemblyOrderCreateImpl.Codeunit.al` (70013424); `AssemblyOrderPostImpl.Codeunit.al` (70013425); `AssemblyOrderReopenImpl.Codeunit.al` (70013427); `CostGetImpl.Codeunit.al` (70013468); `CostToGLTestImpl.Codeunit.al` (70013467); `RevaluationCalcImpl.Codeunit.al` (70013488); `ItemApplGetImpl.Codeunit.al` (70013490); `ItemApplReapplyImpl.Codeunit.al` (70013492); `ItemApplUnapplyImpl.Codeunit.al` (70013491); `PeriodGetImpl.Codeunit.al` (70013483); `PhysInvtPostImpl.Codeunit.al` (70013465); `PhysInvtRecordImpl.Codeunit.al` (70013466); `PhysInvCalcImpl.Codeunit.al` (70013496); `PriceUpdateImpl.Codeunit.al` (70013486); `ReclassPreviewImpl.Codeunit.al` (70013474); `ReservationCancelImpl.Codeunit.al` (70013478); `ReservationCreateImpl.Codeunit.al` (70013476); `ReservationGetImpl.Codeunit.al` (70013477); `TrackingAvailGetImpl.Codeunit.al` (70013473); `TransfDocPrevPostImpl.Codeunit.al` (70013413); `TransferOrderCreateImpl.Codeunit.al` (70013414); `TransferOrderPostImpl.Codeunit.al` (70013415); `TransferOrderReopenImpl.Codeunit.al` (70013417); `TransferOrderStatsImpl.Codeunit.al` (70013419); `TransfOrderReleaseImpl.Codeunit.al` (70013416); `TransfUndoRcptImpl.Codeunit.al` (70013481); `ItemAttrDefCreateImpl.Codeunit.al` (10036900); `ItemAttributeCreateImpl.Codeunit.al` (10036898); `ItemAttributeGetImpl.Codeunit.al` (10036897); `ItemAttributeUpdateImpl.Codeunit.al` (10036899).

### Fixed (2026-10-16) - Icelandic translation resources

- Regenerate `app/Translations/Bifrost Inventory.is-IS.xlf` from the current build: include all 85 generated units using the existing Icelandic source comments and replace the three obsolete numeric-ID entries. Inventory Setup captions, domain captions, posting refusals, assembly/transfer descriptions and attribute help now have matching runtime translation IDs. English source text and AL behavior are unchanged.
- Explicitly mark the five already-temporary Message Argument test variables as `temporary` in `ItemAttributeTestsori.Codeunit.al` (96900), `InvPostingGateTests.Codeunit.al` (96918) and `InvPostingGateGrantTests.Codeunit.al` (96919). This preserves the Foundation table's `TableType = Temporary` behavior and lets the BC 28 analyzer recognize the existing temporary-variable names without AA0237 warnings.

### Fixed (2026-10-15) - contract reads retain payload generation and source position

- `tools/Test-ContractParameterKeys.ps1` versions JSON snapshots and the underlying request payload, applies exhaustive validators at individual read/call sites, and unions conditional paths. Source-checked normalization retains removed keys in the original payload constraint; replacements, streams, unknown effects, implicit calls and try-function/codeunit return boundaries discard stale proof. Unsupported regions retain their reads. JSON key comparisons remain case sensitive (#30).
- The AL statement parser preserves CASE/IF/ELSE ownership across terminators and loop statements. Portable source-proof fixtures, branch parser controls and an independent bounded concrete source oracle retain the counterexamples behind this repair.
- Remaining `tableView` source discrepancies stay visible. Issues #30–33 remain acceptance-open, and production guard wiring stays off. No AL object IDs, contracts, allow-lists, workflow files or app versions change in this tooling repair.

### Fixed (2026-10-15) - preserve request context in contract source checks

- `tools/Test-ContractParameterKeys.ps1` follows nested JSON records through array iteration and helper arguments, while cleared or replaced tokens retain ambiguity diagnostics. It narrows runtime branches only from source-proven literal selectors, fresh local codeunit modes, or an unchanged message envelope at an entry dispatch. Unknown consumers, shared instances, mutation and ambiguous calls retain both paths (#30).
- Dependency source can be supplied with `-DependencyAppFolders`; only the selected app's registrations are scanned. Duplicate object names fail, and invocation evidence must identify the dependency commit and official artifact. Rejection-only checks are reported separately only when a void helper's sole action is a read-only nonempty-value check followed by `Error`; real reads and incorrect declarations remain findings.
- `tools/tests/test-contract-parameter-keys.py` covers positive and negative request lineage, dispatch, dependency and rejection scenarios. The functional candidate's remaining journal-validation findings and newly exposed `tableView` discrepancies remain visible; this does not close #30–33 or enable production workflow wiring. No AL object IDs, contracts, allow-lists or workflow files changed in this tooling repair.

### Fixed (2026-10-15) - typed-reader keys retain literal caller bindings

- `tools/Test-ContractParameterKeys.ps1` resolves a forwarded typed-reader key only when every reached source call supplies a literal for that parameter. Unknown receivers, nested or dynamic arguments, mutable keys, unknown key consumers and overloaded procedures retain the ambiguity diagnostic (#30). This recognizes the existing `skip` and `take` wrapper without a key-name exception.
- `tools/tests/test-contract-parameter-keys.py` adds fifteen caller-binding cases, including undocumented literal keys, multiple callers and unresolved bindings. The remaining production guard findings stay visible; no workflow is enabled.

### Fixed (2026-10-15) - operation selectors are not request parameters

- `tools/Test-ContractParameterKeys.ps1` excludes a literal operation selector only when the resolved callee's source proves that its parameter is used solely in `case` selectors (#30). Unknown calls, additional parameter uses and ambiguous overloads retain the conservative request-key check. No method-name exception or allow-list was added.
- `tools/tests/test-contract-parameter-keys.py` adds eight operation-selector regressions. The full production scan still reports the existing four contract discrepancies at this product base; this repair does not close #30 or enable the production guard.

### Fixed (2026-10-15) - label property scanner respects quoted comments

- `tools/Test-MixedLanguageLabels.ps1` now reads the `Locked` property outside quoted strings and comments. Protocol text such as `allowBlocked=true` in an Icelandic translation comment no longer reports a translated refusal as locked (#33). Actual `Locked = true` labels remain findings.
- `tools/tests/test-mixed-language-labels.py` checks both local and global labels, escaped quotes, property order, case and whitespace, explicit false, and real locked properties. No AL objects, allow-lists or workflow jobs changed.

### Fixed (2026-10-15) - zero-warning Inventory verification

- Preserve the attribute-table grants from `BIFROSTInvRead.PermissionSetExt.al` (10036915) and `BIFROSTInvWrite.PermissionSetExt.al` (10036916) in the included, nonassignable `BIFROSTInvAttrRead.PermissionSet.al` (10036915) and `BIFROSTInvAttrWrite.PermissionSet.al` (10036916). Read and Full roles retain their original access; no posting or Foundation Setup grants are added.
- Align AL filenames with object names and order record declarations before codeunits without changing message execution. `PhysInvCalcImpl.Codeunit.al` (70013496), `PhysInvPreviewImpl.Codeunit.al` (70013472) and `TrackingAvailGetImpl.Codeunit.al` (70013473) clear the notes output when they report no notes.
- Fix test helper content-type buffer lengths, load the item Description field, initialize JSON-array indexes explicitly and name temporary arguments consistently. `InvPostingGateTests.Codeunit.al` (96918) verifies preserved read-only/write attribute access, and `InventoryContractBatchTests.Codeunit.al` (96921) verifies stale notes are cleared. Existing tests and assertions remain enabled.

### Fixed (2026-10-13) - contract source guard recognizes Inventory chapters

- `Test-ContractParameterKeys.ps1` follows a literal shared-chapter selector, literal JSON parameter arrays, attached parameter objects and the typed request readers in Foundation Request Value Reader ori. Unresolved selectors and malformed arrays fail with explicit diagnostics; undeclared and unread keys still fail. Regression fixtures cover valid chapters, mismatches, unrelated objects, cleared objects and dynamic calls. No AL object or message implementation changes.

- `.github/workflows/SourceGuards.yaml` adds the `ContractParameterKeysRegression` job for the guard self-test and Python regression fixtures. Its comments identify the remaining production contract, localization, translation and help-link checks.
- `tools/tests/test-contract-parameter-keys.py` adds 26 regression fixtures for contract selectors, declarations and typed readers, including mismatches and malformed inputs.

### Fixed (2026-10-12) - related help entries name existing message types

- Cost Get Impl ori (70013468) added `Inventory.AdjustCost.Run` and `Inventory.Revaluation.Calculate` as plain strings. Foundation reads a string related entry as message type "", so `Help.Implementation.Get` failed and the UAT roster refresh dropped 50 help documents.
- These codeunits now add related entries as objects with `name` and `useInsteadWhen`: Cost Get Impl ori (70013468), Cost To GL Test Impl ori (70013467), Revaluation Calc Impl ori (70013488), Item Appl. Get Impl ori (70013490), Item Appl. Reapply Impl ori (70013492), Item Appl. Unapply Impl ori (70013491), Period Close Impl ori (70013485), Period Get Impl ori (70013483), Period Reopen Impl ori (70013484), Phys. Inv. Calc Impl ori (70013496), Phys. Inv. Preview Impl ori (70013472), Phys. Invt. Calc Impl ori (70013464), Phys. Invt. Post Impl ori (70013465), Phys. Invt. Record Impl ori (70013466), Price Update Impl ori (70013486), Reclass Check Impl ori (70013475), Reclass Post Impl ori (70013493), Reclass Preview Impl ori (70013474), Reservation Cancel Impl ori (70013478), Reservation Create Impl ori (70013476), Reservation Get Impl ori (70013477), Tracking Assign Impl ori (70013470), Tracking Avail. Get Impl ori (70013473), Tracking Delete Impl ori (70013471), Assembly Undo Post Impl ori (70013482), and Transf Undo Rcpt Impl ori (70013481). Those names are registered message types.
- `Inventory.PhysInventory.Check` was never registered and never published, so dropping it is not a breaking change. Phys. Inv. Preview Impl ori (70013472) no longer names it. The preview still names `Inventory.PhysInventory.Post`. Phys. Inv. Check Impl ori (70013499) had no callers and is removed. The README no longer lists the type.
- Phys. Inv. Post Impl ori (70013497) was not bound to a message type and had no callers. It was never published, so removing it is not a breaking change. `Inventory.PhysInventory.Post` stays on Phys. Invt. Post Impl ori (70013465).
- Inventory Contract Batch Tests (96921) walks every Inventory message type and fails when a related entry is not an object with a non-empty name that exists in the catalogue. This app registers 44 Inventory types. Foundation also registers `Inventory.ItemJournal.Check`, `Inventory.ItemJournal.Create`, `Inventory.ItemJournal.Post`, and `Inventory.ItemJournal.PreviewPost`. Those four have help contracts, so the walk expects 48. They are not unpublished leftovers, and this app does not own them.
- Item Appl. Get Impl ori (70013490) returned false for every contract chapter, so the help reader had no contract for `Inventory.ItemApplication.Get`. It now follows Item Appl. Unapply Impl ori (70013491): envelope, Item Application Entry target, required `itemLedgerEntryNo`, the success response, `MissingParameter`, a read-only effect, and related Unapply and Reapply.
- These registered types whose contract chapters also returned false now declare the chapters their implementations already answer: Reservation Get Impl ori (70013477) `Inventory.Reservation.Get`, Period Get Impl ori (70013483) `Inventory.Period.Get`, Period Close Impl ori (70013485) `Inventory.Period.Close`, Period Reopen Impl ori (70013484) `Inventory.Period.Reopen`, Transf Undo Rcpt Impl ori (70013481) `Inventory.Transfer.UndoReceipt`, Assembly Undo Post Impl ori (70013482) `Inventory.Assembly.UndoPost`, Reclass Post Impl ori (70013493) `Inventory.Reclassification.Post`, Price Update Impl ori (70013486) `Inventory.Price.Update`, and Revaluation Calc Impl ori (70013488) `Inventory.Revaluation.Calculate`.

### Changed (2026-10-12) - empty physical inventory batch returns PreconditionFailed

- Phys. Invt. Post Impl ori (70013465) named error code `NothingToPost`, which `Bifrost Error Code ori` does not have, and the runtime raised that empty batch with no error code. An empty batch is a state precondition, the same case as the core item journal and general journal post. The contract and the runtime now return `PreconditionFailed` on parameter `journalBatchName`. Callers that matched `NothingToPost` or the bare error text now receive `PreconditionFailed`. Inventory Contract Batch Tests (96921) asserts that code on the contract and on an empty batch.

### Fixed (2026-10-11) - direct transfer posting on BC 28.5

- UAT Base Application 28.5.54151.55799 has no `Inventory Setup."Direct Transfer Posting Type"` (AL0132). That enum is new in BC 29. On BC 28.0 through 28.6 the setup field is still the option `Direct Transfer Posting`, with `Receipt and Shipment` and `Direct Transfer`, which is what codeunit 5706 reads.
- Transfer Order Post Impl ori and Transf Doc Prev. Post Impl ori use that option. `Receipt and Shipment` posts the shipment and the receipt together. `Direct Transfer` posts one direct transfer.
- CI now compiles against sandbox artifact 28.5.54151.55751 (w1), the closest published 28.5 artifact at or before UAT 28.5.54151.55799. That UAT build is not in the public w1 index. The Current workflow uses the same pin. Next Minor and Next Major keep `////nextminor` and `////nextmajor`.
- `.AL-Go/settings.json` is a `fullBuildPatterns` entry, so a later artifact pin is a full pull-request build instead of an incremental skip.

### Fixed (2026-10-11) - semantic compile errors on the compile repair

- Cost To GL Post Impl ori and Adjust Cost Run Process ori run reports 1002 and 795 inside a TryFunction, because `Report.Run` returns no value. A failed run is returned with `GetLastErrorText`. Success uses `SetResponseJson`. The costing contract chapters, including the `InvalidOperation` error text, are unchanged.
- Reclass Post Impl ori returns the empty-batch text through `RespondWithError`, because `Bifrost Error Code ori` has no `NothingToPost` value.
- Price Update Impl ori looks up the item with `Document Lookup ori.FindItemRange`.
- Reservation Create Impl ori calls `Reservation Management.AutoReserve`.
- Phys. Inv. Calc Impl ori runs report `Calculate Inventory` from `Microsoft.Inventory.Counting.Journal` through `SetItemJnlLine`.
- Transfer Undo Shpt Impl ori runs `Undo Transfer Shipment` on each shipment line whose `Correction Line` is false. A failure is returned as an error.
- Transfer Order Post Impl ori and Transf Doc Prev. Post Impl ori briefly read BC 29 `Direct Transfer Posting Type`. That reference is replaced by the BC 28 option in the 28.5 fix above.
- Item attribute tests call the registered message types `Inventory.Attribute.Get`, `Inventory.Attribute.Create`, `Inventory.Attribute.Update`, and `Inventory.AttributeDefinition.Create`. Write-restriction checks pass `Force = false`, which Foundation now requires.
- Attribute related chapters name those registered message types. Costing contracts use error code `PreconditionFailed` for a failed report run. `BusinessCentralError` stays the dispatcher failure.
- BIFROST InvRead ori, BIFROST InvWrite ori, and the posting-gate test set can read Inventory Setup ori, so a caller without BIFROST InvPost ori can still evaluate the domain gate. BIFROST InvPost ori keeps the page and tabledata grant used by permission coverage.
- The no-component-stock assembly preview test rereads the component item after the BOM is created, then sets Prevent Negative Inventory.
- Transfer and assembly posting preview stay enabled without BIFROST InvPost ori. Posting still requires that set.

### Fixed (2026-10-11) - remaining main compile blockers

- Object IDs that sat outside `[10036885..10036934]` and `[70013400..70013499]`, and the duplicate codeunit IDs 70013490 and 70013491, now use free IDs inside those ranges. Item Appl. Get Impl ori (70013490) and Item Appl. Unapply Impl ori (70013491) keep their IDs. Reservation Get Impl ori is 70013477 and Reservation Cancel Impl ori is 70013478. App and test versions are unchanged.
- `Inventory.PhysInventory.Calculate` stays on Phys. Inv. Calc Impl ori (70013496), value 70013446. The second registration of that same name is removed. `Inventory.TrackingAvailability.Get` moves to value 70013449.
- Assembly Undo Post Impl ori calls `Assembly-Post.Undo` because codeunit `Pstd. Assembly - Undo` is not in this Business Central version. A failed undo is returned as an error and is not reported as success.
- Transf Undo Rcpt Impl ori no longer calls the missing codeunit `Undo Transfer Receipt`. A posted transfer receipt that exists is answered with an error that this version cannot undo it. Success is not invented.
- Asm. Order Release Impl ori and Assembly Undo Post Impl ori use the `Assembly` domain. Phys. Invt. Post Impl ori (70013465) uses the `PhysInventory` domain.
- BIFROST InvPost ori grants page Inventory Setup ori (70013452) and tabledata Inventory Setup ori, which is the app's only assignable permission set. Foundation table Setup ori is not granted.

### Fixed (2026-10-10) - UAT dependency installation

- UAT feature-app deployment uses the Foundation app already deployed by its own pipeline in Dev scope, avoiding an unauthorized AppSource Foundation installation. `.github/AL-Go-Settings.json`: `DeployToBifrost.DependencyInstallMode = "ignore"`. AppSource delivery is unchanged; no AL objects or IDs change.

### Fixed (2026-10-10) - Attribute chapter selector compatibility

- Inventory Contract Parts ori (70013445) accepts the four registered Inventory Attribute selectors alongside the existing Item helper selectors. Existing chapter payloads, Item-related references and executable implementations Item Attribute Get Impl ori (10036897), Item Attribute Create Impl ori (10036898), Item Attribute Update Impl ori (10036899), and Item AttrDef Create Impl ori (10036900) are preserved; related-name catalogue validation remains a separately tracked blocker.
- Inventory Contract Batch Tests (96921) use the registered names and check exact ordinals, parameter types/required flags/default absence, Item targets, Definition subject/target absence, response fields/effects and existing error/example/overview/notes content through the real contract interface and reader.
- The contract-key guard binds declaration and target calls in lexical scope with separate literal contexts, grouped/nested selectors, forwarders and early exits. Unsupported contexts fail explicitly; budgets are 32 call edges and 256 contexts per chapter root. Existing readers and allowlist remain unchanged, with positive, mismatch, unsupported and boundary controls.

### Fixed (2026-10-10) - literal contract parameter validation

- The contract parameter guard recognizes the literal JSON chapters of Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462), while still reporting unread declarations and undocumented reads. Guard fixtures cover unrelated JSON receivers, comments, AL apostrophe escaping, malformed chapters and empty arrays; costing execution and metadata are preserved.

### Fixed (2026-10-10) - costing metadata interface completeness

- Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462) implement the missing message direction, description and contract chapters with typed defaults, array preconditions and cleared reused outputs. CostToGL metadata discloses report completion without promising G/L posting; existing execution, filters and report options are preserved.
- Inventory Contract Batch Tests (96921) adds six metadata regressions covering defaults, conflicting-filter preconditions, dispatcher error declarations, report options and reused interface outputs.

### Fixed (2026-10-09) - main lexical compile blockers

- Period Close Impl ori (70013485), Period Get Impl ori (70013483), Period Reopen Impl ori (70013484), Phys. Invt. Post Impl ori (70013534), Reclass Post Impl ori (70013493), and Tracking Avail. Get Impl ori (70013542) import their standard Inventory Period, posting, and ledger namespaces verified in BC28 and BC29 shipped packages.
- Reservation WriteGuard ori (70013498) and Tracking Data Restrict ori (70013544) subscribe to the Message Argument ori table (10077896) publisher; restriction bodies and subscriber skip flags are preserved.
- Asm. Order Release Impl ori (70013426) removes a duplicate local declaration while retaining both domain gate calls.
- MsgType.Reserv.EnumExt ori (70013492) shortens the enumextension object name to fit the 30-character limit; value IDs, captions and implementations are preserved.

### Changed (2026-10-07) - preserve the Bifrost pipeline across AL-Go and Alpaca updates

- `Bifrost Pipeline Guards` runs `tools/Test-BifrostPipeline.ps1` and `tools/Test-SharedAlpacaContainer.ps1` when workflows, AL-Go settings, Alpaca scripts, or `AGENTS.md` change. `fullBuildPatterns` includes `.github/workflows/**` and `tools/Test-BifrostPipeline.ps1`, so a pipeline change runs the full Default and Test build.

### Changed (2026-10-05) - align with Bifrost Foundation 28.0.1

- The Foundation dependency floor is **28.0.1.0** in `app/app.json` and `test/app.json`, the same floor as Bifrost Language Models and Bifrost Attachments.
- The Inventory table already declares `Extensible = false`; no table or page change was needed.
- `tools/` carries Foundation's source guards. The Source Guards workflow runs the checks that already pass on Attachments: no call stack in answers, validated table views, no obsolete, permission coverage, and Icelandic keyword counts. Contract-parameter and mixed-language guards are copied but not wired in.
- Parsing and field-write checks use Request Value Reader ori; posting previews use Posting Preview Helper ori; transfer/assembly/item lookup uses Document Lookup ori, preserving existing request and response behavior. Migrated objects: Item Attribute Resolve ori (10036908), Asm. Doc Prev. Post Impl ori (70013423), Asm. Order RefreshLn Impl ori (70013421), Asm. Order Release Impl ori (70013426), Asm. Order Statistics Impl ori (70013422), Assembly Order Create Impl ori (70013424), Assembly Order Post Impl ori (70013425), Assembly Order Reopen Impl ori (70013427), Transf Doc Prev. Post Impl ori (70013413), Transfer Order Create Impl ori (70013414), TransferOrder-Post (Yes/No) (5706), Transfer Order Reopen Impl ori (70013417), Transfer Order Stats Impl ori (70013419), Transf. Order Release Impl ori (70013416), Item Attribute Get Impl ori (10036897).
- Real Icelandic discovery keywords replace filler in Assembly Order Create Impl ori (70013424), Assembly Order Post Impl ori (70013425), and Transfer Order Create Impl ori (70013414); generated Icelandic translations follow the AL comments.
- Regression coverage extends Asm. Doc Prev. Post Tests (96905), Transfer Order Create Tests (96913), and Transfer Order Stats. Tests (96917) for preview response fields, posting failure, typed input rejection, and lookup errors.
- Help Links is not wired in until `businesscentralal/bifrost` main has `help/inventory/`.

### Changed (2026-10-04) - CI/CD builds only main; every pull request gets a Pull Request Build

- Build policy only, no app change. `CI/CD` runs on pushes to `main` only, and `Pull Request Build` runs for pull requests into any branch. `.github/AL-Go-Settings.json` sets `CICDPushBranches` to `main` and `CICDPullRequestBranches` to `**`, so Update AL-Go System Files keeps the triggers.

### Changed (2026-10-01) - code style of the message contracts

- The contract procedures of all 17 message type codeunits are written one statement per line (84 CodeCop AA0018 warnings), empty `GetNotes` stubs clear their `var` parameter (AA0150), and three file names match their object names (AA0215). No behaviour change.

### Removed (2026-10-01) - markdown help procedure (#23)

- Every Inventory message type codeunit drops `GetMessageHelpAsMarkdownDocument`, the empty compatibility shim. Foundation removed it from `Msg Interface ori` (core#198); help is the contract chapters that `Help.Implementation.Get` returns. No chapter changed.
- Bifrost Foundation dependency raised to 28.0.0.186, the first Foundation build without the procedure, in `app/app.json` and `test/app.json`.

### Added (2026-09-30) - Inventory message contracts (#24)

- All 17 Inventory message types now implement `Msg Contract ori` and expose envelope, target, parameters, response, errors, effect, related, workflow, examples, overview, and notes chapters where applicable.
- All 17 message types expose distinct English and Icelandic discovery keywords and selection descriptions.
- Per-type markdown help codeunits were removed after their content moved into contract chapters; the legacy markdown interface method remains as an empty compatibility shim for issue #23.
- The app and test projects now pin Bifrost Foundation `28.0.0.166`; contract conformance, effect, and discovery tests cover the full batch.

### Added (2026-09-29) - Transfer and assembly order message types (#20)

- Inventory.TransferOrder.* and Inventory.AssemblyOrder.* message types now live in Bifrost Inventory (moved from Foundation). Field-write checks, transfer-line handling, preview shaping, and typed date, decimal, and boolean reads go through public Dispatcher ori. PreviewPost no longer checks posting permission. Anyone who posts transfer or assembly orders through Bifrost now needs BIFROST InvPost ori, because BIFROST ItemPost ori no longer covers Inventory.TransferOrder.Post or Inventory.AssemblyOrder.Post. Foundation TakeOver does not assign BIFROST InvPost ori, so admins must grant it manually. Transfer and Assembly PreviewPost help matches the Success answer: every Success answer carries entryCount and glEntryCount, balanced is omitted when glEntryCount is 0, and Business Central posting errors come back verbatim with no code.

### Changed (2026-09-25) - Latest Foundation CI build (floor 28.0.0.0)

- The app builds against the latest Foundation CI build with a Foundation floor of `28.0.0.0`.
- App and test Bifrost Foundation dependency version set to `28.0.0.0`.
- AL-Go `appDependencyProbingPaths` for bc-origo-bifrost-core: `release_status: latestBuild`, `version: latest`. GetArtifacts matches a specific version exactly; only `latest` uses the last successful CICD run.
### Security

- Default (release) builds no longer ship the test app's internalsVisibleTo grant; the strip moved to PipelineInitialize.ps1 because Alpaca never ran PreCompileApp.ps1 (core#129).

### Fixed (2026-09-25) - Deploy to Bifrost sandbox rejected as a version downgrade

- CI/CD run [36029236028](https://github.com/businesscentralal/bc-origo-bifrost-inventory/actions/runs/36029236028) failed at Deploy to Bifrost: `Cannot install the extension Bifrost Inventory by Origo 28.0.0.12 because a newer version 28.0.10.0 was already installed.`
- Cause: #16 switched AL-Go to `versioningStrategy: 3` (major.minor.build from app.json, run number as revision). Earlier builds used strategy 0 (run number as build) and deployed `28.0.10.0`, so every strategy-3 build (`28.0.0.<run>`) was lower than the installed version.
- Fix: app and test `version` raised to `28.1.0.0`; `versioningStrategy: 3` kept. Test dependency on Bifrost Inventory moved to `28.1.0.0` so tests always resolve the rebuilt app.

### Changed (2026-09-17) - Bifrost Foundation Exact pin 28.0.0.100 (no float)

- App/test Bifrost Foundation dependency set to Exact `28.0.0.100`.
- AL-Go `appDependencyProbingPaths` for bc-origo-bifrost-core: `release_status: latestBuild`, `version: 1.0.0.100`.
- `nuGetFeedSelectMode: Exact` so NuGet does not resolve `[28.0.0.100,)` upward to colliding `.107`.

### Changed

- App manifest: privacy statement and EULA URLs now point at the published Bifröst Foundation pages; Application Insights connection string updated to the shared bc-cosmos-shared telemetry resource. Help and publisher URL unchanged.
- App logo: new Bifröst wordmark with "Powered by origo." tagline; app-name line unchanged.

## Bifrost Inventory 28.0.0.0

### Added
- App scaffold for Bifrost Inventory (Foundation 28.0.0.0 dependency, idRanges 10036885–10036934).
- Message types: `Item.Attribute.Get`, `Item.Attribute.Create`, `Item.Attribute.Update`, `Item.AttributeDefinition.Create`.
- PermissionSetExtensions `BIFROST InvRead ori` / `BIFROST InvWrite ori` onto Foundation Read/Full (no own assignable set).
- AC-9: `Data.Records.Set` refused on Item Attribute tables 7500/7501/7504/7505; Get remains allowed.
