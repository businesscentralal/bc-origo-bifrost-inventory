namespace Origo.Bifrost.Inventory;

codeunit 70013434 "Transfer Order Stats Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.TransferOrder.Statistics - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Returns Transfer Order line totals - matching what BC Page 5755 "Transfer Statistics" displays. Iterates `Transfer Line` rows where `Derived From Line No. = 0` and aggregates `Quantity`, `Net Weight`, `Gross Weight`, `Unit Volume`, and `Units per Parcel`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound (read-only)  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Safe and idempotent. No writes occur.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Order Identification');
        HelpBuilder.AppendLine('Standard `Transfer Header` identification:');
        HelpBuilder.AppendLine('1. `subject` parsed as GUID -> header `SystemId`.');
        HelpBuilder.AppendLine('2. `subject` as text -> header `No.`.');
        HelpBuilder.AppendLine('3. Request JSON keys (every key supplied is tried; identifiers that point to different records are refused): `systemId`, `recordSystemId`, `id`, `documentNo`, `transferOrderNo`, `no`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine('None beyond identification.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Examples');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Inventory.TransferOrder.Statistics", "subject": "TO000456" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.TransferOrder.Statistics",');
        HelpBuilder.AppendLine('  "data": { "documentNo": "TO000456" }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "documentNo": "TO000456",');
        HelpBuilder.AppendLine('  "transferFromCode": "BLUE",');
        HelpBuilder.AppendLine('  "transferToCode": "RED",');
        HelpBuilder.AppendLine('  "directTransfer": false,');
        HelpBuilder.AppendLine('  "statusValue": "Open",');
        HelpBuilder.AppendLine('  "postingDate": "2026-04-15",');
        HelpBuilder.AppendLine('  "shipmentDate": "2026-05-01",');
        HelpBuilder.AppendLine('  "receiptDate": "2026-05-03",');
        HelpBuilder.AppendLine('  "totals": {');
        HelpBuilder.AppendLine('    "lineCount": 2,');
        HelpBuilder.AppendLine('    "quantity": 30,');
        HelpBuilder.AppendLine('    "parcels": 3,');
        HelpBuilder.AppendLine('    "netWeight": 45,');
        HelpBuilder.AppendLine('    "grossWeight": 60,');
        HelpBuilder.AppendLine('    "volume": 0.9');
        HelpBuilder.AppendLine('  }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success`. Lookup failures use the error envelope. |');
        HelpBuilder.AppendLine('| documentNo / transferFromCode / transferToCode / directTransfer | Header echo. |');
        HelpBuilder.AppendLine('| statusValue | `Open` or `Released`. Field is `statusValue` (not `status`) because `status` is reserved for the response envelope. |');
        HelpBuilder.AppendLine('| postingDate / shipmentDate / receiptDate | Format `0,9`. |');
        HelpBuilder.AppendLine('| totals.lineCount | Number of `Transfer Line` rows considered (excludes derived-from lines). |');
        HelpBuilder.AppendLine('| totals.quantity | Sum of `Quantity` across lines. |');
        HelpBuilder.AppendLine('| totals.parcels | Sum of `ceil(Quantity / "Units per Parcel")` across lines that have a positive Units per Parcel. |');
        HelpBuilder.AppendLine('| totals.netWeight / totals.grossWeight | Sum of `Quantity * Net Weight` / `Quantity * Gross Weight`. |');
        HelpBuilder.AppendLine('| totals.volume | Sum of `Quantity * Unit Volume`. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Transfer Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, transferOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Transfer Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.PreviewPost` - see predicted ledger entries.');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Post` - ship and/or receive.');

        HelpText := HelpBuilder.ToText();
    end;
}
