namespace Origo.Bifrost.Inventory;

/// <summary>
/// Help markdown for Item.Attribute.Update.
/// </summary>
codeunit 10036903 "Item Attribute Update Help ori"
{
    Access = Internal;

    /// <summary>Returns the help document as markdown.</summary>
    /// <returns>Markdown help text.</returns>
    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Item.Attribute.Update - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('Changes an existing item↔attribute mapping value and returns before/after. Mapping must already exist — otherwise use `Item.Attribute.Create`.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Item.Attribute.Update", "subject": "1000", "data": { "attributes": [ { "name": "Color", "value": "Red" } ] } }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "status": "Success", "itemNo": "1000", "results": [ { "attributeName": "Color", "before": "Blue", "after": "Red", "attributeId": 1, "valueId": 5 } ] }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- `Item.Attribute.Create`');
        HelpBuilder.AppendLine('- `Item.Attribute.Get`');
        HelpText := HelpBuilder.ToText();
    end;
}
