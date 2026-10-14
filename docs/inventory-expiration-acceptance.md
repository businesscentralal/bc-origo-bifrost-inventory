# Inventory #5 expiration acceptance

Binding Architect disposition [1791931218.380149](https://bifrst-group.slack.com/archives/C0C0XM70YF8/p1791931218380149) withdraws 1791930111.133289 and reinstates 1791928739.191239. The amended issue was read back at [comment 6157467946](https://github.com/businesscentralal/bc-origo-bifrost-inventory/issues/5#issuecomment-6157467946).

- With Item Tracking Code **Use Expiration Dates** enabled, use the ledger/reservation/tracking entry's own native Expiration Date.
- Disabled or undated entries return blank, never `0D` as a date string.
- Grouped lot/package availability returns blank when the open positive entries disagree.
- Master-data precedence was **struck** from AC-5 on 13 October. It is neither pending nor waived. No master field or table extension is invented.

Native runtime evidence used Base Application 28.5.54151.56140: tables 6505 Lot No. Information and 6515 Package No. Information contain no Expiration Date field. The original sanitized schema/download evidence and hashes are retained in the shared Inventory acceptance evidence exported for Architect; native regressions cover enabled, disabled, undated and lot/package disagreement. Current-tip compile/full-suite/UI and licensed MCP remain separate mandatory acceptance evidence.

The older correction asserting master fields was withdrawn; historical evidence is retained in the owner checkpoint rather than represented as the current contract.
