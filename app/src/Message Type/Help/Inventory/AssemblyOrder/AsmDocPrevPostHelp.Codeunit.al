namespace Origo.Bifrost.Inventory;

codeunit 70013437 "Asm. Doc Prev. Post Help ori"
{
    Access = Internal;

    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Inventory.AssemblyOrder.PreviewPost - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('Simulates posting an Assembly Order and returns the captured ledger entries (Item Ledger, Value Entry, G/L Entry where applicable) without committing. Uses BC `Gen. Jnl.-Post Preview.SetContext(Assembly-Post, AssemblyHeader)` then `Run()` and the `Posting Preview Event Handler` to capture entries before BC rolls back.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Idempotency / Safety');
        HelpBuilder.AppendLine('Safe and idempotent. The transaction is always rolled back. No `Posted Assembly Header`, ledger entries, or No. Series numbers persist after the call. `rollback: true` is included in every successful response to make this explicit.');
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
        HelpBuilder.AppendLine('{ "type": "Inventory.AssemblyOrder.PreviewPost", "subject": "AO000123" }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "type": "Inventory.AssemblyOrder.PreviewPost",');
        HelpBuilder.AppendLine('  "data": { "documentNo": "AO000123" }');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{');
        HelpBuilder.AppendLine('  "status": "Success",');
        HelpBuilder.AppendLine('  "rollback": true,');
        HelpBuilder.AppendLine('  "summary": "Assembly Order AO000123 (BICYCLE x 5) preview produced 4 entries. No G/L entries would be posted.",');
        HelpBuilder.AppendLine('  "documentNo": "AO000123",');
        HelpBuilder.AppendLine('  "itemNo": "BICYCLE",');
        HelpBuilder.AppendLine('  "locationCode": "BLUE",');
        HelpBuilder.AppendLine('  "quantityToAssemble": 5,');
        HelpBuilder.AppendLine('  "lcyCode": "USD",');
        HelpBuilder.AppendLine('  "predictedNumbers": { "postedAssemblyNo": "PA000045" },');
        HelpBuilder.AppendLine('  "totals": { "totalDebitLCY": 0, "totalCreditLCY": 0 },');
        HelpBuilder.AppendLine('  "preview": [');
        HelpBuilder.AppendLine('    { "tableId": 32, "tableName": "Item Ledger Entry", "entryCount": 4, "entries": [] }');
        HelpBuilder.AppendLine('  ]');
        HelpBuilder.AppendLine('}');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Property | Description |');
        HelpBuilder.AppendLine('|----------|-------------|');
        HelpBuilder.AppendLine('| status | `Success` whenever the preview completed; `Error` if preview itself threw. |');
        HelpBuilder.AppendLine('| rollback | Always `true` - reminder that nothing was persisted. |');
        HelpBuilder.AppendLine('| summary | Human-readable one-liner combining document, item, quantity, entry count, and balance state. |');
        HelpBuilder.AppendLine('| documentNo / itemNo / locationCode / quantityToAssemble | Echo of header fields. |');
        HelpBuilder.AppendLine('| lcyCode | `General Ledger Setup."LCY Code"`. |');
        HelpBuilder.AppendLine('| predictedNumbers.postedAssemblyNo | First captured `Posted Assembly Header.No.` (the document number that would be assigned at real post). |');
        HelpBuilder.AppendLine('| totals.balanced | Present only when G/L entries were captured (`glEntryCount > 0`): `true` when `Round(totalDebitLCY - totalCreditLCY, 0.01) = 0`. Omitted when the posting creates no G/L entry. |');
        HelpBuilder.AppendLine('| totals.totalDebitLCY / totals.totalCreditLCY | Sums of G/L Entry debit/credit (LCY) - typically zero for non-stockkeeping/non-cost-accounting items. |');
        HelpBuilder.AppendLine('| preview[] | One element per captured table. Each contains `tableId`, `tableName`, `entryCount`, `entries` (subset of fields configured by `Bifrost Preview Helper`). |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Preview Outcome');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('The preview answers `Success` only when it captured at least one entry. Every answer carries `entryCount` (all captured entries) and `glEntryCount` (the G/L entries among them).');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- **Nothing would be posted** (no entry captured, or BC reports that there is nothing to post): `status: Error`, `code: NothingToPreview`, `error: "The preview produced no entries. Nothing would be posted."` and a `nextStep`: Quantity to Assemble is 0. Review with `Inventory.AssemblyOrder.Statistics`.');
        HelpBuilder.AppendLine('- **No G/L entries** (for example item or value entries with Automatic Cost Posting off): `Success` with `glEntryCount: 0` and **no** `totals.balanced`; the summary says "No G/L entries would be posted."');
        HelpBuilder.AppendLine('- **G/L entries**: `totals.balanced` as described above.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|-------|-------|');
        HelpBuilder.AppendLine('| `The preview produced no entries. Nothing would be posted.` (`NothingToPreview`) | Nothing would be posted. `nextStep`: Quantity to Assemble is 0. Review with `Inventory.AssemblyOrder.Statistics`. |');
        HelpBuilder.AppendLine('| `Assembly Header identifier is missing. Pass it as the subject, or as one of: systemId, recordSystemId, id, documentNo, assemblyOrderNo, no.` (`MissingParameter`) | No identifier in `subject` or the request JSON. |');
        HelpBuilder.AppendLine('| `Assembly Header "{value}" was not found (from {subject or key}).` (`RecordNotFound`) | An identifier was given but matches no record; `parameter` and `received` name it. Every identifier supplied is tried. |');
        HelpBuilder.AppendLine('| `The identifiers in {a} and {b} point to different records.` (`ConflictingIdentifiers`) | Two identifiers were given that resolve to different records. |');
        HelpBuilder.AppendLine('| `"{value}" is not a valid GUID` / `integer` `(from {key}).` (`InvalidParameterFormat`) | A SystemId or entry number that cannot be read. |');
        HelpBuilder.AppendLine('| `Assembly order %1 has no lines to post.` | Order had zero `Assembly Line` rows. `%1` is the document `No.`. |');
        HelpBuilder.AppendLine('| `Posting preview failed and no entries were captured. The assembly order cannot be posted in its current state.` | `Gen. Jnl.-Post Preview.Run` failed without surfacing a specific BC error text. |');
        HelpBuilder.AppendLine('| (BC posting error text) | Preview captured a real BC posting error - returned verbatim. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Post` - actually post once preview is clean.');
        HelpBuilder.AppendLine('- `Inventory.AssemblyOrder.Statistics` - inspect costs without simulation.');

        HelpText := HelpBuilder.ToText();
    end;
}
