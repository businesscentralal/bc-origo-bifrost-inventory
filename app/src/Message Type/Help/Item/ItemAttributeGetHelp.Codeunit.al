namespace Origo.Bifrost.Inventory;

/// <summary>
/// Help markdown for Item.Attribute.Get.
/// </summary>
codeunit 10036901 "Item Attribute Get Help ori"
{
    Access = Internal;

    /// <summary>Returns the help document as markdown.</summary>
    /// <returns>Markdown help text.</returns>
    internal procedure GetHelpText() HelpText: Text
    var
        HelpBuilder: TextBuilder;
    begin
        HelpBuilder.AppendLine('# Item.Attribute.Get - Help');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Overview');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('Returns attribute definitions and assigned values for one or more items without multi-table `Data.Records.Get` joins.');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('**Direction**: Outbound (read-only)  **Content-Type**: `text/json`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Identifier Resolution Order');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('1. `subject` — GUID = `Item.SystemId`, otherwise `Item.No.`');
        HelpBuilder.AppendLine('2. `data.itemNo`');
        HelpBuilder.AppendLine('3. `data.itemId` / `data.id` / `data.systemId` / `data.recordSystemId`');
        HelpBuilder.AppendLine('4. `data.tableView`');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Request Parameters');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Parameter | Type | Required | Notes |');
        HelpBuilder.AppendLine('|---|---|---|---|');
        HelpBuilder.AppendLine('| `includeUnassigned` | boolean | No | Default false. When true, lists defined attributes with empty values. |');
        HelpBuilder.AppendLine('| `attributeNames` | string[] | No | Filter by attribute name. |');
        HelpBuilder.AppendLine('| `attributeIds` | integer[] | No | Filter by attribute id. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('### Request Example');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "type": "Item.Attribute.Get", "subject": "1000", "data": { "attributeNames": ["Color"] } }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Response Shape');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('```json');
        HelpBuilder.AppendLine('{ "status": "Success", "items": [ { "itemNo": "1000", "itemSystemId": "...", "attributes": [ { "attributeId": 1, "attributeName": "Color", "type": "Option", "unitOfMeasure": "", "valueId": 3, "value": "Blue", "numericValue": null, "dateValue": null } ] } ] }');
        HelpBuilder.AppendLine('```');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Errors');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('| Error | Cause |');
        HelpBuilder.AppendLine('|---|---|');
        HelpBuilder.AppendLine('| `No items found matching the specified criteria.` | Empty resolved item set. |');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('## Related Message Types');
        HelpBuilder.AppendLine('');
        HelpBuilder.AppendLine('- `Item.Attribute.Create`');
        HelpBuilder.AppendLine('- `Item.Attribute.Update`');
        HelpBuilder.AppendLine('- `Item.AttributeDefinition.Create`');
        HelpText := HelpBuilder.ToText();
    end;
}
