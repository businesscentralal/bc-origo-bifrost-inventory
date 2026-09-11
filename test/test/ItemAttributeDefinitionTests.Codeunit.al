namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Item.AttributeDefinition.Create.
/// </summary>
codeunit 96901 "Item AttrDef Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure DefinitionCreate_Option_CreatesValues()
    var
        RequestJson: JsonObject;
        OptionValues: JsonArray;
        ResponseJson: JsonObject;
        UniqueName: Text;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        UniqueName := 'Finish' + Format(CreateGuid(), 0, 4);
        RequestJson.Add('name', UniqueName);
        RequestJson.Add('type', 'Option');
        OptionValues.Add('Matte');
        OptionValues.Add('Gloss');
        RequestJson.Add('optionValues', OptionValues);

        ResponseJson := Library.ExecuteType(MessageType::"Item.AttributeDefinition.Create", '', RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Contains('attributeId'), 'attributeId');
        Assert.IsTrue(ResponseJson.Contains('createdValues'), 'createdValues');
    end;

    [Test]
    procedure DefinitionCreate_DuplicateName_ReturnsError()
    var
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.CreateOptionAttribute('Dup', ItemAttribute, ValueA, ValueB);

        RequestJson.Add('name', ItemAttribute.Name);
        RequestJson.Add('type', 'Option');

        ResponseJson := Library.ExecuteType(MessageType::"Item.AttributeDefinition.Create", '', RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Error');
    end;
}
