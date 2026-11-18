# Inventory tests

## Issue 186

Codeunit 96964 (`Inv. 186 Blank Line Tests ori`) covers Check/Preview/Post blank-row parity in LCID 1033 and 1039. Fixtures create their own X-prefixed stock and journals; run under the standard test runner rollback isolation.

Codeunit 96925 (`Reclass Journal Tests ori`) covers reclassification journal Check/PreviewPost/Post, including bilingual dispatcher scenarios. It moved from 96964 to preserve main's blank-line test codeunit at 96964.
