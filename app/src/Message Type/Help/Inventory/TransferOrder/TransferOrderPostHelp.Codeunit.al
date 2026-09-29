namespace Origo.Bifrost.Inventory;

codeunit 70013431 "Transfer Order Post Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.TransferOrder.Post - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Posts a Transfer Order via BC codeunit 5706 `TransferOrder-Post (Yes/No)`. Behaviour depends on the header `Direct Transfer` flag:');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- **Non-direct transfer**: caller must supply `postingType = "Ship"` or `"Receive"`. BC posts only the requested side.');
        HelpBuilder.AppendLine('- **Direct transfer**: `postingType` is ignored. BC reads `Inventory Setup."Direct Transfer Posting"` and posts either a single Direct Transfer or Receipt + Shipment.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Not idempotent. `Commit()` is issued before posting. Successful posting writes Item Ledger Entries, Value Entries, and Posted Transfer Shipment / Receipt records, and increments `Last Shipment No.` / `Last Receipt No.` on the header. Posting failures roll back via `Codeunit.Run`/BC and return `status: "Error"` with the BC text.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('Implementation binds the `Transfer Post Subscriber` to override `OnBeforeGetPostingOptions` so the StrMenu prompt is suppressed and the chosen ship/receive/transfer flags are injected.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Order Identification');
        HelpBuilder.AppendLine('Standard `Transfer Header` identification:');
        HelpBuilder.AppendLine('1. `subject` parsed as GUID -> header `SystemId`.');
        HelpBuilder.AppendLine('2. `subject` as text -> header `No.`.');
        HelpBuilder.AppendLine('3. Request JSON keys (every key supplied is tried; identifiers that point to different records are refused): `systemId`, `recordSystemId`, `id`, `documentNo`, `transferOrderNo`, `no`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine('| Field | Type | Required | Description |');
        HelpBuilder.AppendLine('|-------|------|----------|-------------|');
        HelpBuilder.AppendLine('| postingType | Text | Required for non-direct transfers, ignored for direct | `"Ship"` or `"Receive"` (case-insensitive). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Examples');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.TransferOrder.Post",');
        HelpBuilder.AppendLine('  "subject": "TO000456",');
        HelpBuilder.AppendLine('  "data": { "postingType": "Ship" }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Inventory.TransferOrder.Post", "subject": "TO000457" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "documentNo": "TO000456",');
        HelpBuilder.AppendLine('  "postingType": "Ship",');
        HelpBuilder.AppendLine('  "directTransfer": false,');
        HelpBuilder.AppendLine('  "postedShipmentNo": "PTS00012",');
        HelpBuilder.AppendLine('  "postedReceiptNo": "",');
        HelpBuilder.AppendLine('  "postingDate": "2026-04-15"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` on completed posting; `Error` otherwise. |');
        HelpBuilder.AppendLine('| documentNo | Original Transfer Order `No.`. |');
        HelpBuilder.AppendLine('| postingType | `Ship`, `Receive`, or `DirectTransfer` (for direct transfers). Echoes the supplied case for non-direct. |');
        HelpBuilder.AppendLine('| directTransfer | Header flag. |');
        HelpBuilder.AppendLine('| postedShipmentNo | Set when `Last Shipment No.` advanced during this post. Empty otherwise. |');
        HelpBuilder.AppendLine('| postedReceiptNo | Set when `Last Receipt No.` advanced during this post. Empty otherwise. |');
        HelpBuilder.AppendLine('| postingDate | Posting Date on the header after posting (Format `0,9`). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Posting Gate');
        HelpBuilder.AppendLine('Calling this message type requires the `BIFROST InvPost ori` permission set in addition to `BIFROST API ori`. `BIFROST ItemPost ori` no longer covers this message type. Without `BIFROST InvPost ori` the request returns: `Posting denied: missing ''BIFROST InvPost ori'' permission set.`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Posting denied: missing ''BIFROST InvPost ori'' permission set.` | Caller lacks the `BIFROST InvPost ori` permission set. `BIFROST ItemPost ori` does not grant it. |');
        HelpBuilder.AppendLine('| `Transfer Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, transferOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Transfer Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| `For a non-direct transfer order, postingType must be "Ship" or "Receive".` | Non-direct transfer and `postingType` omitted. |');
        HelpBuilder.AppendLine('| `postingType must be "Ship", "Receive", or "ShipReceive". Received: {value}` | `postingType` had an unsupported value, or `ShipReceive`/`Ship+Receive` was requested for a non-direct transfer (not supported by BC in one step). |');
        HelpBuilder.AppendLine('| (BC posting error text) | `TransferOrder-Post (Yes/No).Run` threw (e.g. insufficient inventory, unreleased order). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.PreviewPost` - simulate before posting.');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Release` - release before posting.');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Statistics` - inspect totals.');

        HelpText := HelpBuilder.ToText();
    end;
}
