# Contract errors

After Foundation core#711, document lookup answers `InvalidParameterFormat` when `data` is not a JSON object, or when an identifier key is an object, an array, `null`, or a number where text is expected. Several wrong values come back as one `MultipleErrors`. A missing or empty key stays `MissingParameter`. Entry numbers still accept numbers.

Document types that resolve an identifier list these error codes:

- `InvalidParameterFormat` on `data`
- `InvalidParameterFormat` on the identifier key
- one `MultipleErrors` entry

This applies to transfer order, assembly order, undo, and reservation create lookups. Contract tests still have to assert those codes after the Foundation publish.

## Issue status on main 147e8a6

- #34 reclassification check refuses a non-Transfer template and accepts `templateName` and `batchName`. Preview and post are implemented.
- #35 adjust cost runs report 795. Cost to G/L post and test are implemented.
- #36 domain flags and the domain gate are implemented. Inventory Setup is blocked from `Data.Records.Set`.
- #37 tracking assign and delete go through Item Tracking Management and include package.
- #38 attribute types use `Inventory.Attribute.*`.
- #39 undo shipment, receipt, and assembly call the standard undo codeunits.
- #40 item application unapply and reapply call `Item Jnl.-Post Line`.
- #30-#33 stay unwired in SourceGuards.yaml until the guards pass and infrastructure review approves them.
- #27 contract tests are not written yet. They wait for the Foundation publish.

## Costing metadata (PR #90 draft)

Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462) declare the existing costing contracts. Optional string parameters have empty-string defaults; postToGL defaults to Boolean false. Report 795 receives either the item or category filter, truncated to 250 characters, and rejects two nonempty effective filters. Report 1002 receives no request filters or explicit Post initialization; its success response confirms report completion and response construction, not G/L posting. Both contracts preserve potential write/posting risks without a safe-retry guarantee.

The error declarations distinguish the report Run=false response from raised report/conversion errors and Foundation's scheduled-task failure handler. Synchronous dispatch and direct invocation do not themselves establish that scheduled response mapping. Runtime conversion, posting and failure-handler evidence remains pending.

Inventory Contract Batch Tests (96921) contains six costing metadata regressions for typed defaults, filter preconditions, error declarations, report options and reused interface outputs. They have not run: the app still fails compilation, so this draft supplies no runtime, permission or financial execution proof.

## Native tracking/reservation candidate (#5/#7/#36/#37)

`Inventory.Tracking.Get` reads a line identified by `source: {type, systemId}`; sales/purchase/transfer also accept `documentType` plus `documentNo`/`lineNo`, `documentType` plus `systemId`, or the line SystemId as subject. Qualified document types are `Sales.Order`, `Sales.Invoice`, `Sales.CreditMemo`, `Sales.ReturnOrder`, corresponding `Purchase.*` values, and `Transfer.Order`. Unqualified `Order` remains the legacy sales selector. Transfers default to Outbound and accept `transferDirection: Inbound`. Item reads retain Foundation item lookup (`subject`, `itemNo`, `itemId`, `id`, `systemId`, `recordSystemId`).

The response identifies each row as `ReservationEntry`, `TrackingSpecification` or `ItemLedgerEntry`. Source pointers include the stable `sourceType` name, numeric `sourceTableNo`/`sourceSubtype`, document number, batch, production line and reference line; reservation-pair sides are distinguished by `positive`. Pending tracking and posted handling are separate records. Quantities are base units. No persistent tracking, reservation or ledger record is written by a read.

Exact `lotNo`, `serialNo`, `packageNo`, `variantCode`, `locationCode` values may include blank. `locationFilter` accepts BC filter syntax and intersects `locationCode`. `skip` is nonnegative; `take` is 1..10000, default 100. `noOfLines` counts returned rows; `totalNoOfLines` counts matching rows before paging. An empty tracking set returns `RecordNotFound`; a page beyond the end of a nonempty set returns an empty successful page.

`Inventory.TrackingAvailability.Get` returns `availability`, grouped by lot/serial/package, location and variant, with `inventory`, `qtyReserved` and `availableQuantity`. Reserved quantities come from each posted entry's native `Reserved Quantity` FlowField. Only open positive item ledger positions contribute. Under the [Architect AC-5 amendment](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791928739191239), expiration dates are taken from native entries only when the item tracking code has Use Expiration Dates enabled; otherwise they are blank. If entries in a group disagree, the grouped date is blank. BC28.5 Lot/Serial/Package No. Information tables have no stored Expiration Date field; no master field or table extension is added. Platform source findings and tests are documented in [expiration acceptance](inventory-expiration-acceptance.md).

`Inventory.Reservation.Get` accepts the same document/source forms, item identifiers, `entryNo` and tracking/location filters. All supplied criteria intersect before entry-not-found is evaluated. An entry number identifies a native reservation pair; supply/demand rows are distinguished by source and positive, rather than silently discarding one side.

Create accepts a native source object or legacy document keys. Supply is either an explicit `supply` object or `itemLedgerEntryNo`; specifying both is refused. Omitting both requests matching posted inventory, allocated in entry order through native Create Reserv. Entry adapters after whole-quantity availability checks. No AutoReserve is used. The response includes `quantityBase` and the resulting `entryNo` or `entryNos`. Requested tracking must match a selected ledger entry; serial allocations are one base unit. Quantity input uses the source UOM. Cancel accepts document/source keys or entry number and preserves native paired cancellation.

These are implementation contracts, not a claim of full issue acceptance. Complete source scenarios, restricted permissions, concurrent writes, UI/MCP and external dependencies remain tracked in the worker-8 acceptance matrix. No older “done on main” sentence above supersedes current evidence.
