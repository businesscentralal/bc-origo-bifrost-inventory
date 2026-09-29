namespace Origo.Bifrost.Inventory;

codeunit 70013433 "Transfer Order Reopen Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.TransferOrder.Reopen - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Reopens a Released Transfer Order so it can be edited. Delegates to the isolated `Transfer Order Reopen Process` codeunit via `Codeunit.Run` (BC `LockTable` is not allowed inside the outer TryFunction, but is allowed inside `Codeunit.Run`).');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Idempotent. Reopening an already-`Open` order returns `Success` with `statusBefore = Open` and `statusAfter = Open` without touching BC.');
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
        HelpBuilder.AppendLine('{ "type": "Inventory.TransferOrder.Reopen", "subject": "TO000456" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.TransferOrder.Reopen",');
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
        HelpBuilder.AppendLine('  "statusBefore": "Released",');
        HelpBuilder.AppendLine('  "statusAfter": "Open"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` (including the already-open no-op path); `Error` if `Transfer Order Reopen Process` failed. |');
        HelpBuilder.AppendLine('| documentNo | Transfer Order `No.`. |');
        HelpBuilder.AppendLine('| transferFromCode / transferToCode / directTransfer | Header echo. |');
        HelpBuilder.AppendLine('| statusBefore | `Released` or `Open` - value before reopen was attempted. |');
        HelpBuilder.AppendLine('| statusAfter | Always `Open` on success. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Transfer Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, transferOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Transfer Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC validation error text) | `Transfer Order Reopen Process` failed (rare). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.TransferOrder.Release` - return to Released.');
        HelpBuilder.AppendLine('- `Data.Records.Set` on `Transfer Line` - edit lines once Open.');

        HelpText := HelpBuilder.ToText();
    end;
}
