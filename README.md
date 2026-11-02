# Inventory #176 verification

Candidate `25b223a6619a7884a8c64c90b3e7708b55b85b81`; retained source owner Dáinn (worker-7).

| Check | Actual result |
|---|---|
| Product and test compilation, both dependency profiles | Each0errors/0warnings; CodeCop/UICop/AppSourceCop |
| Full native suite, Foundation28.0.3.530 | 464executed/464passed/0failed/0skipped |
| Full native suite, Foundationmain28.0.11.656 | 464executed/464passed/0failed/0skipped |
| New native AC01 | All9 irreversible types: valid owned targets, missing/wrong/matching counts, real posting/undo/costing/journal success, no ledger changes on refusals;1033/1039 |
| Web Client | TransferOrder.Post native catalogue help download, integer expectedCount and confirmed example;3checks each in1033/1039; English language restored |
| Self-seeded MCP | 94executed/94passed/0failed/0skipped;92calls;11touched types plus definition Retryable help |
| MCP cleanup | Final2items created201/deleted204/absence200; every earlier aborted-harness item also deleted with verified absence |
| Owned cleanup | Mainf07d572102a0 and floorf05fb077d871 each DELETE204, independent GET404 |
| Other guards | is-IS sync; no en-US XLF; unique IDs; unchanged-main AppSourceCop compatibility comparison all pass |

MCP exercises confirmation preview/mismatch and matching-count handler routing, costing success on self-created zero-stock items, deliberate absent-own-document/batch refusals, attribute empty-array parity and shared Retryable. Successful native posting/undo/journal effects are separately asserted by the full suite. No customer/shared fixtures, EULA/trial/licence/backend writes, HTTP enabling or write-guard changes. Posted native fixture state was removed with the owned environments.

Foundationmain: published TestApps artifact13126632957, exact mainSHA`c8177c806854795271d45eaa682a3737ee8ddabf`, installed28.0.11.656, includes #1151. The issue's .2147483647.1919 refers to an older PR-numbered build; the supported floor remains28.0.3.530.

The raw standards snapshot gateway is16/23: inherited whole-file XML/naming/read-isolation findings, procedure-semicolon false positives, a modernization substring warning and a version-heading check against the repository's Unreleased changelog. Every reported app declaration/statement/pattern was checked against original main source; see raw findings and disposition. No suppression and no fully-green gateway claim. Compiler/native/XLF/object/compatibility are independently green.

Earlier failed development and MCP parser attempts remain in the retained private checkpoint. The MCP harness recognizes expected structured refusals and the documented uncoded missing-assembly/native absent-batch refusals; no product assertion was weakened.

PR CI, independent Claude verification, Grok clearance, approval, Architect merge/deployment and Tester UAT remain separate stages. This artifact is not an issue-completion claim.
