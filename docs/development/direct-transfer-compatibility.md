# Direct Transfer compilation targets

Issue #228 keeps the supported BC 28.5 build and the BC 29 build warning-free without suppressing diagnostics.

| Symbols | Product and test compiler arguments | Inventory Setup field | Shipment/receipt member |
| --- | --- | --- | --- |
| BC 28.5 | No additional symbol | 5855 `Direct Transfer Posting` (option) | `Receipt and Shipment` |
| BC 29 | No additional symbol | 5857 `Direct Transfer Posting Type` (enum) | `Shipment and Receipt` |

The replacement field and enum do not exist in BC 28.5. After merging the runtime compatibility fix from PR #213, both targets detect field 5857 through RecordRef and otherwise use field 5855. BC 28 option values 0/1 map to BC 29 enum values 10/20. No compiler define is required; an existing `/define:BC29` is harmless. Compile the product and tests against matching Microsoft packages.

The change affects the setup reads in `Inventory.TransferOrder.Post` and `Inventory.TransferOrder.PreviewPost`, plus the matching setup writes/restoration in the test helper. It preserves the two existing choices: shipment plus receipt, or one direct-transfer document. No public procedure, message contract, permission, page, label, or translation changes.

Run test codeunits 96912 (transfer preview) and 96914 (transfer posting) on the owned tenant. Existing cases cover both preview modes and partial shipment/receipt posting; the new single-document posting case checks exactly one posted direct transfer, both response numbers identifying that document, no separate shipment or receipt headers, and removal of the fully posted order. Compile both apps against both symbol sets with CodeCop, UICop and AppSourceCop. Runtime tests and bilingual MCP checks are separate from compilation evidence.
