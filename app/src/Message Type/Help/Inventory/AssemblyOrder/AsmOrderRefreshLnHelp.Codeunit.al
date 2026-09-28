namespace Origo.Bifrost.Inventory;

codeunit 70013435 "Asm. Order RefreshLn Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.AssemblyOrder.RefreshLines - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Refreshes the component lines of an Open Assembly Order by re-validating the header `Item No.`. This re-creates `Assembly Line` rows from the current parent item BOM and discards any previous manual edits to those lines.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Functionally idempotent (re-running produces the same lines), but **destructive**: any manual changes to component lines are lost. The order must be `Open` - BC raises an error for `Released` orders.');
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
        HelpBuilder.AppendLine('{ "type": "Inventory.AssemblyOrder.RefreshLines", "subject": "AO000123" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.AssemblyOrder.RefreshLines",');
        HelpBuilder.AppendLine('  "data": { "documentNo": "AO000123" }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "documentNo": "AO000123",');
        HelpBuilder.AppendLine('  "itemNo": "BICYCLE",');
        HelpBuilder.AppendLine('  "quantity": 5,');
        HelpBuilder.AppendLine('  "linesBefore": 0,');
        HelpBuilder.AppendLine('  "linesAfter": 3');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success`. Failures (e.g. released order) use the error envelope. |');
        HelpBuilder.AppendLine('| documentNo | Assembly Order `No.`. |');
        HelpBuilder.AppendLine('| itemNo | Parent item. |');
        HelpBuilder.AppendLine('| quantity | Header `Quantity`. |');
        HelpBuilder.AppendLine('| linesBefore | Number of `Assembly Line` rows before the refresh. |');
        HelpBuilder.AppendLine('| linesAfter | Number of `Assembly Line` rows after the refresh. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `Assembly Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, assemblyOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Assembly Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| (BC validation error text) | Released order, missing BOM, or other BC validation failure on `Item No.`. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Create` - create a new order.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Reopen` - return a Released order to Open before refreshing.');

        HelpText := HelpBuilder.ToText();
    end;
}
