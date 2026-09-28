namespace Origo.Bifrost.Inventory;

codeunit 70013432 "Transf. Order Release Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.TransferOrder.Release - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Releases an Open Transfer Order so it can be posted. Calls `Codeunit.Run` on the BC `Release Transfer Document` codeunit.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Idempotent. Releasing an already-`Released` order returns `Success` with `statusBefore = Released` and `statusAfter = Released` without touching BC.');
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
        HelpBuilder.AppendLine('{ "type": "Inventory.TransferOrder.Release", "subject": "TO000456" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.TransferOrder.Release",');
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
        HelpBuilder.AppendLine('  "statusBefore": "Open",');
        HelpBuilder.AppendLine('  "statusAfter": "Released"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` (including the already-released no-op path); `Error` if `Release Transfer Document.Run` failed. |');
        HelpBuilder.AppendLine('| documentNo | Transfer Order `No.`. |');
        HelpBuilder.AppendLine('| transferFromCode / transferToCode / directTransfer | Header echo. |');
        HelpBuilder.AppendLine('| statusBefore | `Open` or `Released` - value before release was attempted. |');
        HelpBuilder.AppendLine('| statusAfter | Always `Released` on success. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Transfer Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, transferOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Transfer Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC validation error text) | `Release Transfer Document.Run` failed (missing in-transit code, invalid lines, etc.). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Reopen` - reverse the release.');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Post` - ship and/or receive after release.');

        HelpText := HelpBuilder.ToText();
    end;
}
