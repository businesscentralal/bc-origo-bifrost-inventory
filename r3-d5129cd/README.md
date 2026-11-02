# Inventory #176 — current candidate verification

Candidate `d5129cd6ae5a06a60c22ec187a44c8ec1533e2f9`; retained source owner Dáinn (worker-7), existing PR177. This directory supersedes historical25b223a evidence for runtime verification. Branch publication and immutable commit read back from GitHub before runtime verification.

| Check | Actual exact-tip result |
|---|---|
| Product and test compile, both dependency profiles | Each0errors/0warnings with CodeCop/UICop/AppSourceCop |
| Full configured native suite, Foundation28.0.3.530 | 464executed/464passed/0failed/0skipped |
| Full configured native suite, Foundationmain28.0.11.656 | 464executed/464passed/0failed/0skipped |
| BC Web Client through Playwright MCP | 3contract assertions in1033,4assertions in1039 including translated description;7passed/0failed/0skipped |
| Self-seeded origo-bc-mcp | 94named checks passed/0failed/0skipped,92calls,11touched types; LCIDs1033/1039 |
| MCP fixture cleanup | Both items created201/deleted204; independent filtered queries200/empty |
| Owned environment cleanup | Mainf0c8d36d33b1 and floorf01a320b6d03 deleted204; independent GET404 for each |
| Compatibility | Candidate against original released main baseline:0errors/0warnings |
| Guards | is-IS sync, unique objects and contract keys pass; no en-US XLF |

Native codeunit96978 exercises all9irreversible types with valid self-created targets, no-ledger-change assertions for missing/wrong counts and successful actual posting/undo/costing/journal actions, in1033/1039. Shared errors are checked separately from exact raw application metadata; the supported Foundation floor remains530. Malformed attribute payload tests retain exact code/text assertions in both languages.

MCP covers all9preview/mismatch/matching-handler paths, costing success on self-created zero-stock items, deliberate unique absent-document/batch native refusals, empty-array attribute parity and shared Retryable metadata. Successful posting effects are verified by native tests separately. No EULA/trial/licence/counter/backend writes, HTTP enabling, guard suppression or customer/shared fixtures. Normal Inventory domains were enabled through native UI solely in the owned environment. English UI restored before deletion. Native fixture state removed with both environments.

Foundationmain provenance: TestApps artifact13126632957 at c8177c806854795271d45eaa682a3737ee8ddabf, version28.0.11.656 containing core#1151. The issue cites an older PR-numbered .2147483647.1919 build; those numbering schemes are not compared numerically.

Current standards snapshot52ba4754cfd614e4a7c50af87b30149b18b313e3, captured2026-11-02T10:35:08.581Z. The unchanged scanner first hit an unset USERPROFILE Linux fallback-path error, then completed with USERPROFILE=/home/node at17/23. Remaining findings match previously compared original-main declarations/patterns;14one-statement findings are procedure parameter separators, including the changed private Boolean signature. Raw/disposition results are disclosed; no fully-green gateway claim or suppression.

Learning: dependency-composed metadata and explicit dispatcher language were previously untested assumptions; preserve exact raw metadata, check framework additions separately and pass explicit LCID. Current native dual-dependency results and94MCP checks verify these scoped repairs. Retained failed attempts remain private.

Paired CI, guarded review handoff, independent Claude receipt, Grok clearance, eligible approval, Architect merge/deploy, Tester same-SHA UAT and actual issue closure remain separately tracked. This evidence is not issue completion.
