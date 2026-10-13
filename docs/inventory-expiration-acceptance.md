# Inventory #5 expiration acceptance

Architect correction [1791930111.133289](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791930111133289) supersedes amendment 1791928739.191239. Published AC-5 remains: use Lot/Package No. Information master expiration when Use Expiration Dates is enabled and a master record exists; otherwise use the entry expiration; otherwise blank. Serial master data has no expiration field. Disabling the flag does **not** hide an entry date.

The entry fallback and blank paths have native regression coverage. Master precedence is still incomplete and is not waived. No field, extension or verification result is invented to bridge the schema discrepancy.

Fresh symbols downloaded from the owned BC runtime report Base Application **28.5.54151.56140**, SHA-256 `45d316e688cb6fda14c4f0f18090d896c63e3c526678050e0594571e519448ed`. Its SymbolReference and table source for Lot No. Information (6505) and Package No. Information (6515) expose Date Filter (21, FlowFilter) and Expired Inventory (24, Decimal FlowField), but do not expose an Expiration Date field. The compiled official 28.5.54151.56071 package has the same result. This is a finding about these exact packages; it does not establish which extensions or schema exist in the separately cited live sandbox.

Architect has been asked to supply the exact field IDs, declaring extension/version and target dependency, or reconcile the target schema. Retained evidence: `resume-1/runtime-base-download.json`, `runtime-expiration-fields.json` and the original `expiration-platform-finding.json`. The original broad absence claim and its entry-only AC disposition are superseded; the exact-package field lists remain evidence. No request to narrow AC-5 is implied.

Test codeunit 96927 covers native dated tracking, disabled-flag entry fallback, undated blank output and grouped disagreement. Defensive disagreement fixtures are explicitly temporary in-memory ledger records; posted ledger rows are never changed to manufacture the condition. These tests do not claim master-precedence coverage.

The [MCP correction1791929479.341519](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791929479341519) keeps licensed self-seeded MCP required before PR review, pending [#95](https://github.com/businesscentralal/bc-origo-bifrost-inventory/issues/95). No trial or EULA acceptance is authorized here.
