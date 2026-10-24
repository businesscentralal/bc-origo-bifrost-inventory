# Changelog

## [Unreleased]

### Fixed

- Issue151 first refusal family: Period.Close/Reopen (10076877/10076879) validate ISO dates before lookup, report missing periods with invariant dates and actionable translated context; AdjustCost.Run process10076859 validates boolean/filter values before running report795 and collects independent format errors. Native bilingual regression codeunit96975. Additional issue151 repairs collect assembly/transfer/attribute-definition/reservation/cost inputs, code assembly undo/transfer posting and cost guards, translate preview summaries, return invariant Reservation.Get statuses and ignore only truly empty physical-posting rows. Journal helper10076840 now raises coded rollback-safe refusals and native line context; tracking helpers10076841/10076925 provide expected values and next actions. Metadata, isolated lookup collection and explicit test fixtures are updated; runtime/independent verification remains tracked at each candidate.

### Fixed — issue #150
- Tracking.Assign/Get/Delete now round-trip native source-bound lot, serial and package tracking. A source line SystemId is required; deletion affects only the selected unreserved entry. Single-entry response fields are retained, native posting remains separate and Omit Commit retains caller transaction ownership.
- UndoShipment explicitly refuses received transfer lines with PreconditionFailed and a return-transfer next step; the selected-shipment repair is inherited from #159.
- Correction to the earlier shipped roster: UndoReceipt is disabled, not a working undo feature. The released enum remains for compatibility only; no native Undo Transfer Receipt codeunit exists in the configured BC symbols. Use a new transfer order for received goods. Historical changelog entries describe earlier releases, not current availability.
- Objects: codeunits 10076897 Tracking Assign Impl ori, 10076899 Tracking Delete Impl ori, 10076900 Tracking Get Impl ori, 10076910 Transfer Undo Shpt Impl ori, 10076911 Transf Undo Rcpt Impl ori; new codeunit 10076925 Inventory Tracking Write ori; permission extension 10076836 BIFROST InvWrite ori; new test codeunit 96974 Inv. Source Tracking Tests ori; test codeunit 96914 Transfer Order Post Tests and explicit fixture codeunit/page 96973. Updated README, contracts and is-IS translations.

### Fixed (2026-10-24) - Native reclassification preview and reservation consistency (#159, partial)

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
- Message type enum values follow: each value is the ID of its implementation codeunit (for example `Inventory.Cost.Get` 10076860 on `Cost Get Impl ori`). `Inventory.PhysInventory.Record` takes the ID of `Phys. Invt. Record Impl ori` (10076882); `Inventory.PhysInventory.RecordCount`, which shares that codeunit, is 10076925.
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
