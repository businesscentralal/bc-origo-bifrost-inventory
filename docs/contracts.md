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
