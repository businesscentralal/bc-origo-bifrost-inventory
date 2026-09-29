namespace Origo.Bifrost.Inventory;

codeunit 70013440 "Asm. Order Release Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.AssemblyOrder.Release - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Releases an Open Assembly Order so it can be posted. Calls `Codeunit.Run` on the BC `Release Assembly Document` codeunit.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Idempotent. Releasing an already-`Released` order returns `Success` with `statusBefore = Released` and `statusAfter = Released` without touching BC.');
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
        HelpBuilder.AppendLine('{ "type": "Inventory.AssemblyOrder.Release", "subject": "AO000123" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.AssemblyOrder.Release",');
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
        HelpBuilder.AppendLine('  "statusBefore": "Open",');
        HelpBuilder.AppendLine('  "statusAfter": "Released"');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` (including the already-released no-op path); `Error` if `Release Assembly Document.Run` failed. |');
        HelpBuilder.AppendLine('| documentNo | Assembly Order `No.`. |');
        HelpBuilder.AppendLine('| systemId | Header `SystemId` (Format `0,4`). |');
        HelpBuilder.AppendLine('| itemNo | Parent item. |');
        HelpBuilder.AppendLine('| statusBefore | `Open` or `Released` - the value before release was attempted. |');
        HelpBuilder.AppendLine('| statusAfter | Always `Released` on success. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Assembly Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, assemblyOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Assembly Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC validation error text) | `Release Assembly Document.Run` failed (e.g. lines missing required fields, insufficient inventory). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Reopen` - reverse the release.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Post` - post after release.');

        HelpText := HelpBuilder.ToText();
    end;
}
