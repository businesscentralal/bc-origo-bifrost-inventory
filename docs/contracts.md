# Contract errors

After Foundation core#711, document lookup answers `InvalidParameterFormat` when `data` is not a JSON object, or when an identifier key is an object, an array, `null`, or a number where text is expected. Several wrong values come back as one `MultipleErrors`. A missing or empty key stays `MissingParameter`. Entry numbers still accept numbers.

Document types that resolve an identifier list these error codes:

- `InvalidParameterFormat` on `data`
- `InvalidParameterFormat` on the identifier key
- one `MultipleErrors` entry

This applies to the eleven TransferOrder and AssemblyOrder types that look up a Transfer Header or Assembly Header through Foundation's `Document Lookup ori` (Release, Reopen, Post, PreviewPost and Statistics; Assembly also RefreshLines). Undo, reservation, tracking and the other types read their keys directly and are not covered. Inv. Lookup Contract Tests (96922) asserts the errors chapters, including exactly one `MultipleErrors` entry and none on the Create and Item types. Inv. Lookup Format Tests (96923) sends malformed `data`, wrong-typed identifiers, two wrong keys, an empty identifier and a valid subject with a wrong key through the public dispatcher. The runtime answers need a Foundation build with core#711 (28.0.2 or later).

## Issue status on main 147e8a6

- #34 reclassification check refuses a non-Transfer template and accepts `templateName` and `batchName`. Preview and post are implemented.
- #35 adjust cost runs report 795. Cost to G/L post and test are implemented.
- #36 domain flags and the domain gate are implemented. Inventory Setup is blocked from `Data.Records.Set`.
- #37 tracking assign and delete use native item tracking and include package, assembly and item journal sources. Delete accepts one entryNo, an entryNos array, or omitted entry numbers for all unreserved source tracking (maximum 200). Disabled tracking writes return PreconditionFailed, per Claude Code's acceptance correction of 16.11.2026, with localized Inventory Setup recovery guidance. Other domain error contracts are unchanged.
- #38 attribute types use `Inventory.Attribute.*`.
- #39 is partial: shipment selection and assembly recreation call the native undo paths. Receipt undo remains disabled because the BC 28 source and BC 29 symbols have no native receipt-undo codeunit; see merged PR #185.
- #40 item application unapply and reapply call `Item Jnl.-Post Line`.
- #30-#33 stay unwired in SourceGuards.yaml until the guards pass and infrastructure review approves them.
- #27 contract tests are 96922 (errors chapters) and 96923 (runtime answers).

## Costing metadata (PR #90 draft)

Adjust Cost Run Impl ori (10076858) and Cost To GL Post Impl ori (10076861) declare the existing costing contracts. Optional string parameters have empty-string defaults; postToGL defaults to Boolean false. Report 795 receives either the item or category filter, truncated to 250 characters, and rejects two nonempty effective filters. Report 1002 receives no request filters or explicit Post initialization; its success response confirms report completion and response construction, not G/L posting. Both contracts preserve potential write/posting risks without a safe-retry guarantee.

The error declarations distinguish the report Run=false response from raised report/conversion errors and Foundation's scheduled-task failure handler. Synchronous dispatch and direct invocation do not themselves establish that scheduled response mapping. Runtime conversion, posting and failure-handler evidence remains pending.

Inventory Contract Batch Tests (96921) contains six costing metadata regressions for typed defaults, filter preconditions, error declarations, report options and reused interface outputs. They have not run: the app still fails compilation, so this draft supplies no runtime, permission or financial execution proof.

## Item application selectors and quantities (#40)

- Get accepts `itemNo` or `itemLedgerEntryNo`; when both are present they intersect. Optional `locationCode` and `variantCode` filter matching ledger entries exactly (empty strings mean blank codes). Applications linked to either side are deduplicated by application entry number and include `inboundEntry`/`outboundEntry` objects.
- Unapply accepts `itemLedgerEntryNo` for all linked real applications in one transaction. Legacy `entryNo` still selects one application; do not send both forms. Inbound self-applications are not real applications and cannot be unapplied. Native refusal rolls back all changes.
- Reapply accepts `outboundEntryNo`, `inboundEntryNo`, and positive `quantity` in base units. Both entries must have sufficient unreserved remaining quantity and matching item, location and variant. Native `Item Jnl.-Post Line.ReApply` runs with a scoped quantity event and validates both resulting ledger deltas before success. Legacy `itemLedgerEntryNo`/`applyToEntryNo` retains native remaining-quantity behavior without `quantity`.
- The BC 28 Application Worksheet uses codeunit 22 (`Item Jnl.-Post Line`), confirmed on StefanMaron `w1-28` before implementation. Table 339 is changed only by native application logic. Cost adjustment is separate; effect remains `read` for Get and `write` for Unapply/Reapply.
- Pending AC: Foundation's non-extensible error enum does not contain `DomainDisabled`; the shared gate still returns `InvalidParameter` for a disabled domain. This is not a completed #40 acceptance claim.

## Inventory.ItemSubstitution.Get

```json
{"type":"Inventory.ItemSubstitution.Get","data":{"itemNo":"1000","variantCode":"RED"}}
```

Reads direct Item Substitution (5715) records for an existing item and its exact source variant. Omitted or empty `variantCode` selects only the blank variant. Returns `status`, `itemNo`, `variantCode` and `substitutes` (an empty array is a successful result).

| Parameter | Required | Meaning |
|---|---|---|
| `itemNo` | Yes | Existing item number, at most 20 characters. |
| `variantCode` | No | Existing source variant, at most 10 characters; blank selects the blank variant. |

Each substitute includes `substituteType` (`item` or `nonstockItem`), `substituteNo`, `substituteVariantCode`, `description`, `interchangeable`, `inventory` and `inventoryKnown`. Inventory is current on-hand quantity in base units for the exact substitute variant across all locations. It does not deduct reservations or include future supply, and is not a delivery promise. Catalog substitutes have `inventoryKnown=false` and `inventory=0`.

The effect is `read`. No item is created, cached quantity updated, or reciprocal/recursive relationship inferred. Enable **Item Substitution** on **Inventory Setup**; the setup guide displays the switch without changing it. Read access is required for Inventory Setup, Item Substitution, Item, Item Variant and Item Ledger Entry.

Unknown items and variants return `RecordNotFound`. Missing, wrongly typed, overlong or unknown parameters return `MissingParameter`, `InvalidParameterFormat`, `InvalidParameter` or `UnknownParameter`. Disabled domains and missing read permissions return `InvalidParameter` and `PermissionDenied`. Every refusal includes a translated `nextStep`. Use `Help.MessageType` for the complete contract; Foundation returns public help chapters in English for either LCID. App help labels and refusal guidance have is-IS translations. Use `Inventory.AvailabilityByPeriod.Get` for projected availability by period.
