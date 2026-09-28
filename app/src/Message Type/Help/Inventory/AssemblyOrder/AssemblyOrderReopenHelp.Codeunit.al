namespace Origo.Bifrost.Inventory;

codeunit 70013441 "Assembly Order Reopen Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.AssemblyOrder.Reopen - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Reopens a Released Assembly Order so it can be edited again. Internally delegates to the isolated `Assembly Order Reopen Process` codeunit via `Codeunit.Run` (so BC can `LockTable` outside the outer TryFunction context).');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Idempotent. Reopening an already-`Open` order returns `Success` with `statusBefore = Open` and `statusAfter = Open` without touching BC.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Order Identification');
        HelpBuilder.AppendLine('Standard `Assembly Header` identification:');
        HelpBuilder.AppendLine('1. `subject` parsed as GUID -> header `SystemId`.');
        HelpBuilder.AppendLine('2. `subject` as text -> header `No.` (with `Document Type = Order`).');
        HelpBuilder.AppendLine('3. Request JSON keys (every key supplied is tried; identifiers that point to different records are refused): `systemId`, `recordSystemId`, `id`, `documentNo`, `assemblyOrderNo`, `no`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine('None beyond identification.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Examples');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Inventory.AssemblyOrder.Reopen", "subject": "AO000123" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.AssemblyOrder.Reopen",');
        HelpBuilder.AppendLine('  "data": { "documentNo": "AO000123" }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "documentNo": "AO000123",');
        HelpBuilder.AppendLine('  "systemId": "00000000-0000-0000-0000-000000000000",');
        HelpBuilder.AppendLine('  "itemNo": "BICYCLE",');
        HelpBuilder.AppendLine('  "statusBefore": "Released",');
        HelpBuilder.AppendLine('  "statusAfter": "Open"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` (including the already-open no-op path); `Error` if `Assembly Order Reopen Process` failed. |');
        HelpBuilder.AppendLine('| documentNo | Assembly Order `No.`. |');
        HelpBuilder.AppendLine('| systemId | Header `SystemId` (Format `0,4`). |');
        HelpBuilder.AppendLine('| itemNo | Parent item. |');
        HelpBuilder.AppendLine('| statusBefore | `Released` or `Open` - the value before reopen was attempted. |');
        HelpBuilder.AppendLine('| statusAfter | Always `Open` on success. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Assembly Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, assemblyOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Assembly Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC validation error text) | `Assembly Order Reopen Process` failed. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Release` - return to Released.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.RefreshLines` - refresh BOM lines once Open again.');

        HelpText := HelpBuilder.ToText();
    end;
}
