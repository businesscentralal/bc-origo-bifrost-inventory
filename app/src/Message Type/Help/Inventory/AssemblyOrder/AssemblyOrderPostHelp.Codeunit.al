namespace Origo.Bifrost.Inventory;

codeunit 70013439 "Assembly Order Post Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.AssemblyOrder.Post - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Posts an Assembly Order by calling BC `Assembly-Post.Run`. Optionally overrides `Posting Date` and `Quantity to Assemble` before posting. After posting, the response includes the posted document number plus (when discoverable) the matching Posted Assembly Header `SystemId` and quantity.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Not idempotent. Successful posting deletes the source `Assembly Header` row, writes a `Posted Assembly Header`, Item Ledger Entries, and Value Entries. `Commit()` is issued before posting. Posting failures roll back via `Codeunit.Run`/BC and return `status: "Error"` with the BC message.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Order Identification');
        HelpBuilder.AppendLine('Standard `Assembly Header` identification:');
        HelpBuilder.AppendLine('1. `subject` parsed as GUID -> header `SystemId`.');
        HelpBuilder.AppendLine('2. `subject` as text -> header `No.` (with `Document Type = Order`).');
        HelpBuilder.AppendLine('3. Request JSON keys (every key supplied is tried; identifiers that point to different records are refused): `systemId`, `recordSystemId`, `id`, `documentNo`, `assemblyOrderNo`, `no`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine('| Field | Type | Required | Description |');
        HelpBuilder.AppendLine('|-------|------|----------|-------------|');
        HelpBuilder.AppendLine('| postingDate | Date | No | `YYYY-MM-DD`. Omitted: the header posting date is kept. An invalid value is an error. |');
        HelpBuilder.AppendLine('| quantityToAssemble | Decimal | No | JSON number, or a string with `.` and no thousands separator. Applied only when `> 0`. An invalid value is an error. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Examples');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Inventory.AssemblyOrder.Post", "subject": "AO000123" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.AssemblyOrder.Post",');
        HelpBuilder.AppendLine('  "data": { "documentNo": "AO000123", "quantityToAssemble": 2 }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "documentNo": "AO000123",');
        HelpBuilder.AppendLine('  "postedDocumentNo": "PA000045",');
        HelpBuilder.AppendLine('  "itemNo": "BICYCLE",');
        HelpBuilder.AppendLine('  "postingDate": "2026-04-15",');
        HelpBuilder.AppendLine('  "assembledQuantityBefore": 0,');
        HelpBuilder.AppendLine('  "assembleToOrder": false,');
        HelpBuilder.AppendLine('  "postedSystemId": "00000000-0000-0000-0000-000000000000",');
        HelpBuilder.AppendLine('  "postedQuantity": 5');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` on completed posting; `Error` otherwise. |');
        HelpBuilder.AppendLine('| documentNo | Original Assembly Order `No.`. |');
        HelpBuilder.AppendLine('| postedDocumentNo | Header `Posting No.` (the posted document number assigned by BC). |');
        HelpBuilder.AppendLine('| itemNo | Parent item. |');
        HelpBuilder.AppendLine('| postingDate | Posting Date used (Format `0,9`). |');
        HelpBuilder.AppendLine('| assembledQuantityBefore | `Assembled Quantity` from the header just before posting. |');
        HelpBuilder.AppendLine('| assembleToOrder | Header `Assemble to Order` flag. |');
        HelpBuilder.AppendLine('| postedSystemId | Only present when the Posted Assembly Header could be located (Format `0,4`). |');
        HelpBuilder.AppendLine('| postedQuantity | Only present when the Posted Assembly Header could be located. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Posting Gate');
        HelpBuilder.AppendLine('Calling this message type requires the `BIFROST ItemPost ori` permission set in addition to `BIFROST API ori`. Without it the request returns: `Posting denied: missing ''BIFROST ItemPost ori'' permission set.`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Posting denied: missing ''BIFROST ItemPost ori'' permission set.` | Caller lacks the `BIFROST ItemPost ori` permission set. |');
        HelpBuilder.AppendLine('| `Assembly Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, assemblyOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Assembly Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC posting error text) | `Assembly-Post.Run` threw (insufficient inventory, missing fields, etc.). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.PreviewPost` - dry run with predicted ledger entries.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Release` - release before posting.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Statistics` - inspect costs / quantities first.');

        HelpText := HelpBuilder.ToText();
    end;
}
