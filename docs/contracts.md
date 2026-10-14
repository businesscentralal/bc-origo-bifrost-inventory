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

`Inventory.TrackingAvailability.Get` returns `availability`, grouped by lot/serial/package, location and variant, with `inventory`, `qtyReserved` and `availableQuantity`. Reserved quantities come from each posted entry's native `Reserved Quantity` FlowField. Only open positive item ledger positions contribute. The current [Architect AC-5 correction](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791930111133289) requires master expiration precedence when enabled and available, then the native entry date (including when the flag is disabled), then blank. Entry fallback and blank output are implemented; master precedence is **pending**, because the target's downloaded symbols do not expose the specified master field. The earlier entry-only acceptance amendment is superseded. Grouped entry-date disagreement returns blank. See [expiration acceptance](inventory-expiration-acceptance.md) for the exact platform evidence and outstanding schema dependency.

`Inventory.Reservation.Get` accepts the same document/source forms, item identifiers, `entryNo` and tracking/location filters. All supplied criteria intersect before entry-not-found is evaluated. An entry number identifies a native reservation pair; supply/demand rows are distinguished by source and positive, rather than silently discarding one side.

Create accepts a native source object or legacy document keys. Supply is either an explicit `supply` object or `itemLedgerEntryNo`; specifying both is refused. Omitting both requests matching posted inventory, allocated in entry order through native Create Reserv. Entry adapters after whole-quantity availability checks. No AutoReserve is used. The response includes `quantityBase` and the resulting `entryNo` or `entryNos`. Requested tracking must match a selected ledger entry; serial allocations are one base unit. Quantity input uses the source UOM. Cancel accepts document/source keys or entry number and preserves native paired cancellation. Both Create and Cancel refuse a source with no native outstanding quantity. An open, unreserved source still cancels idempotently. Cancel returns `entriesCancelled`, `itemNo`, `quantityUnreserved` in source units and `quantityBaseUnreserved` in base units. W1 permits reservation pairs on transfer journal lines; ordinary adjustment journal sources retain the native refusal without partial writes.

These are implementation contracts, not a claim of full issue acceptance. Complete source scenarios, restricted permissions, concurrent writes, UI/MCP and external dependencies remain tracked in the worker-8 acceptance matrix. No older “done on main” sentence above supersedes current evidence.


## Current retained costing implementation (#4, #35)

This source supersedes the historical costing snapshot above; it does not mark either issue complete.

- `Inventory.Price.Update` selects exactly one Item through Foundation subject/identifier/named-field tableView rules. It requires `unitPrice` (number or invariant decimal string), refuses unsupported fields, checks native Item/Unit Price field permissions and requires explicit `allowBlocked` for blocked Items. Native Validate/Modify executes in the outer write transaction or an isolated Codeunit.Run; subscriber failures roll back. Response includes actual previous and resulting unit price.
- `Inventory.Revaluation.Calculate` runs native report 5899 into an explicitly identified **empty Revaluation batch**. Required `postingDate` and output `documentNo`; optional native item/location/variant filters, `calculatePer` (`Item Ledger Entry` or `Item`) and per-item `byLocation`/`byVariant`. It does not post or update Standard Cost. Returns actual created-line counts and calculated/revalued totals. Unsupported options refuse before execution.
- `Inventory.Revaluation.Post` and `Inventory.Revaluation.PreviewPost` identify the batch by subject `TEMPLATE|BATCH`/SystemId or data `templateName`/`batchName`/SystemId aliases. Both require a Revaluation template, native journal permissions and the posting gate. Post suppresses inner commits and returns the real native Item Register range. Preview uses BC posting preview and the public Foundation serializer, with captured `preview[]`, `totals` and rollback; journal counts alone are not preview evidence.
- Report 795 accepts its native item/category filters and itemByItem/postToGL options. Reports1002/1003 use their actual pending-entry item/date selection; documentNo is an output option. Native report1003 refusal with mandatory journal templates remains a documented pending configuration gap.

Current delivery still requires zero-warning compilation/publication, current-tip full-suite/UI/licensed self-seeded MCP, reviewed evidence and cleanup. The four foreign permission warnings, Foundation DomainDisabled and licensed runtime #95 remain tracked. Source and native AL checks alone do not establish complete shipping workflow acceptance; external HelpLinks/documentation remains Tryggvi's #31 scope.
