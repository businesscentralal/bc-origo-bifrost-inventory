# Inventory #5 expiration acceptance

Architect amendment [1791928739.191239](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791928739191239) replaces the old three-path AC-5 with native entry dates when Use Expiration Dates is enabled, and blank when disabled. Availability uses open positive entries; differing dates in one lot/package group yield blank.

The official Microsoft Base Application package 28.5.54151.56071 contains no stored Expiration Date on Lot No. Information, Serial No. Information or Package No. Information. Their Date Filter applies to Item Ledger Entry FlowFields. Item Ledger Entry, Reservation Entry and Tracking Specification carry the native date. The original detailed finding is retained at `/workspace/evidence/inventory-functional-worker8/resume-1/expiration-platform-finding.json`; this committed note makes the conclusion and source version accessible with the candidate.

Test codeunit96927 covers enabled and disabled native pending tracking dates, identical grouped dates, and disagreement that stays blank even when a later entry matches the first. Disagreement uses explicitly temporary in-memory ledger inputs because BC normally enforces lot-date consistency; no posted ledger records are modified to manufacture the condition. Actual runtime results belong to the exact-tip evidence, not to this source note.

The later [MCP correction1791929479.341519](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791929479341519) withdraws the Inventory UAT deferral. Licensed self-seeded MCP still must complete before PR review, blocked by [#95](https://github.com/businesscentralal/bc-origo-bifrost-inventory/issues/95). No trial or EULA acceptance is authorized here.
