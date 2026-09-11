namespace Origo.Bifrost.Inventory;

/// <summary>
/// Help markdown for Item.Attribute.Create.
/// </summary>
codeunit 10036902 "Item Attribute Create Help ori"
{
    Access = Internal;

    /// <summary>Returns the help document as markdown.</summary>
    /// <returns>Markdown help text.</returns>
    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Item.Attribute.Create - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('Assigns attribute values to an item. Idempotent when the mapping already has the same value (`changed: false`). A different existing value returns a structured Error unless `overwrite: true`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Item.Attribute.Create", "subject": "1000", "data": { "attributes": [ { "name": "Color", "type": "Option", "value": "Blue", "createValueIfMissing": true } ] } }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "status": "Success", "itemNo": "1000", "results": [ { "attributeName": "Color", "value": "Blue", "changed": true, "attributeId": 1, "valueId": 3 } ] }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|---|---|');
        HelpBuilder.AppendLine('| mapping conflict | Mapping exists with a different value and `overwrite` is not true. |');
        HelpBuilder.AppendLine('| blocked item | Item is Blocked and `allowBlocked` is not true. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- `Item.Attribute.Get`');
        HelpBuilder.AppendLine('- `Item.Attribute.Update`');
        HelpBuilder.AppendLine('- `Item.AttributeDefinition.Create`');
        HelpText := HelpBuilder.ToText();
    end;
}
