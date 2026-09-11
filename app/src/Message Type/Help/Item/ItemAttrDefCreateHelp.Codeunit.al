namespace Origo.Bifrost.Inventory;

/// <summary>
/// Help markdown for Item.AttributeDefinition.Create.
/// </summary>
codeunit 10036904 "Item AttrDef Create Help ori"
{
    Access = Internal;

    /// <summary>Returns the help document as markdown.</summary>
    /// <returns>Markdown help text.</returns>
    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Item.AttributeDefinition.Create - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('Creates an item attribute definition (and optional option values) independently of any item. Duplicate names return a structured Error.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Inbound  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Example');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Item.AttributeDefinition.Create", "data": { "name": "Finish", "type": "Option", "optionValues": ["Matte", "Gloss"] } }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "status": "Success", "attributeId": 2, "attributeName": "Finish", "type": "Option", "createdValues": [ { "valueId": 6, "value": "Matte" } ] }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- `Item.Attribute.Create`');
        HelpBuilder.AppendLine('- `Item.Attribute.Get`');
        HelpText := HelpBuilder.ToText();
    end;
}
