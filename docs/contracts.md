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

## Existing costing contracts

Adjust Cost Run Impl ori (70013460) and Cost To GL Post Impl ori (70013462) now supply their missing interface metadata through the existing enum mappings. No execution gate, request parser or report invocation changes.

- `Inventory.AdjustCost.Run` passes item/category filters to report 795 after truncation to 250 characters; the report rejects two nonempty effective filters. `postToGL` is a report option, and completion does not establish that G/L entries were posted.
- `Inventory.CostToGL.Post` invokes report 1002 without applying request filter fields or explicitly initializing Post. Echoed filter values are response data, not selection evidence.
- A false report return produces the existing `InvalidOperation` answer. Raised report/conversion failures follow the actual caller route; direct invocation may raise, while the normal Foundation scheduled failure handler maps errors to `BusinessCentralError`. Neither contract establishes rollback, idempotence or safe retry.
- Inventory Contract Batch Tests (96921) adds six metadata regressions, preserving its three existing tests. Runtime verification is pending.
