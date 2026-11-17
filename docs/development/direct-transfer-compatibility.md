# Direct Transfer compilation targets

Issue #228 keeps the supported BC 28.5 build and the BC 29 build warning-free without suppressing diagnostics.

| Symbols | Product and test compiler arguments | Inventory Setup field | Shipment/receipt member |
| --- | --- | --- | --- |
| BC 28.5 | No additional symbol | 5855 `Direct Transfer Posting` (option) | `Receipt and Shipment` |
| BC 29 | `/define:BC29` | 5857 `Direct Transfer Posting Type` (enum) | `Shipment and Receipt` |

The replacement field and enum do not exist in BC 28.5. `BC29` is an explicit build symbol, not an automatically detected application version. Always compile the product and tests with the same symbol and matching Microsoft packages. The existing BC 28.5 CI configuration needs no change. When the build target moves to BC 29, its compiler invocation must define `BC29`; once BC 28.5 support ends, remove the conditional branches.

The change affects the setup reads in `Inventory.TransferOrder.Post` and `Inventory.TransferOrder.PreviewPost`, plus the matching setup writes/restoration in the test helper. It preserves the two existing choices: shipment plus receipt, or one direct-transfer document. No public procedure, message contract, permission, page, label, or translation changes.

Run test codeunits 96912 (transfer preview) and 96914 (transfer posting) on the owned tenant. Existing cases cover both preview modes and partial shipment/receipt posting; the new single-document posting case checks exactly one posted direct transfer, both response numbers identifying that document, no separate shipment or receipt headers, and removal of the fully posted order. Compile both apps against both symbol sets with CodeCop, UICop and AppSourceCop. Runtime tests and bilingual MCP checks are separate from compilation evidence.
