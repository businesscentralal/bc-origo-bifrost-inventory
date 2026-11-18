# Inventory tests

## Issue 186

Codeunit 96964 (`Inv. 186 Blank Line Tests ori`) covers Check/Preview/Post blank-row parity in LCID 1033 and 1039. Fixtures create their own X-prefixed stock and journals; run under the standard test runner rollback isolation.

Codeunit 96925 (`Reclass Journal Tests ori`) covers reclassification journal Check/PreviewPost/Post, including bilingual dispatcher scenarios. It moved from 96964 to preserve main's blank-line test codeunit at 96964.

## Re-running the affected suite on a reused local tenant

Use only the worker's assigned tenant, own-compiled packages and `bc_dev_run_tests` with `mode: local`. For PR #195's fixture-related amendment, run the complete codeunits `96918|96921|96925|96930|96941|96944|96945|96947|96948|96965|96970|96976|96977|96978|96981`, without function filters or exclusions.

Before running, inspect the fixture state:

- Microsoft `Library - Utility` uses the `GUID` number series. `Library - ERM` prefixes its generated value with `1` and pads it to 20 characters for G/L accounts. Resetting or removing that series while retaining generated accounts can therefore cause duplicate-account errors. Preserve an existing series and its position. If an absent series needs temporary seeding, first verify the selected range is unused, record the original state and remove only the temporary setup afterwards; never delete existing accounts to make a test pass.
- Codeunit 96965 cleans items whose description starts with `XP117`, vendors with that name prefix, its `XP117T`, `XP117R` and `XP117OTHER` worksheets, and associated documents. Check that these fixtures are absent before starting an independent run. A leftover component referenced by another BOM must not be deleted or have its references removed merely to clear setup. Preserve existing data and use a clean, isolated fixture context on the assigned tenant.

Record the full source SHA, both compiler results, tenant, complete affected-test counts and cleanup readback. Keep failed attempts as evidence; a later passing run does not turn an earlier failure into a pass. The paired full-suite CI must also be green at that SHA. A `ClientSession State is InError` infrastructure failure requires a whole-run rerun, not a source change or a failed-jobs-only rerun.
