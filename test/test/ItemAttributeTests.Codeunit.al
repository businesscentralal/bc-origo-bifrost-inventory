namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Item.Attribute.Get / Create / Update and AC-9 write restriction.
/// </summary>
codeunit 96900 "Item Attribute Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Get_ByItemNo_ReturnsAttributes()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemsToken: JsonToken;
        ItemsArray: JsonArray;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        Mapping.Init();
        Mapping."Table ID" := Database::Item;
        Mapping."No." := Item."No.";
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ValueA.ID);
        Mapping.Insert(true);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Get", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('items', ItemsToken), 'items missing');
        ItemsArray := ItemsToken.AsArray();
        Assert.IsTrue(ItemsArray.Count() > 0, 'expected at least one item');
    end;

    [Test]
    procedure Get_MissingItem_ReturnsError()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Get", 'NO-SUCH-ITEM-ZZZ', RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Error');
    end;

    [Test]
    procedure Create_Idempotent_SameValue_ChangedFalse()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        ResultsToken: JsonToken;
        ResultsArray: JsonArray;
        ResultObj: JsonObject;
        ChangedToken: JsonToken;
        ResultToken: JsonToken;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('type', 'Option');
        AttrObj.Add('value', 'Blue');
        AttrObj.Add('createValueIfMissing', true);
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Create", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Create", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('results', ResultsToken), 'results missing');
        ResultsArray := ResultsToken.AsArray();
        ResultsArray.Get(0, ResultToken);
        ResultObj := ResultToken.AsObject();
        Assert.IsTrue(ResultObj.Get('changed', ChangedToken), 'changed missing');
        Assert.IsFalse(ChangedToken.AsValue().AsBoolean(), 'second call should be changed:false');
    end;

    [Test]
    procedure Create_ConflictWithoutOverwrite_ReturnsError()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        Mapping.Init();
        Mapping."Table ID" := Database::Item;
        Mapping."No." := Item."No.";
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ValueA.ID);
        Mapping.Insert(true);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('value', 'Red');
        AttrObj.Add('overwrite', false);
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Create", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Error');
    end;

    [Test]
    procedure Create_ConflictWithOverwrite_Succeeds()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        Mapping.Init();
        Mapping."Table ID" := Database::Item;
        Mapping."No." := Item."No.";
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ValueA.ID);
        Mapping.Insert(true);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('value', 'Red');
        AttrObj.Add('overwrite', true);
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Create", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');
    end;

    [Test]
    procedure Update_Existing_ReturnsBeforeAfter()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        ResultsToken: JsonToken;
        ResultsArray: JsonArray;
        ResultToken: JsonToken;
        ResultObj: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        Mapping.Init();
        Mapping."Table ID" := Database::Item;
        Mapping."No." := Item."No.";
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ValueA.ID);
        Mapping.Insert(true);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('value', 'Red');
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Update", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('results', ResultsToken), 'results missing');
        ResultsArray := ResultsToken.AsArray();
        ResultsArray.Get(0, ResultToken);
        ResultObj := ResultToken.AsObject();
        Assert.IsTrue(ResultObj.Contains('before'), 'before missing');
        Assert.IsTrue(ResultObj.Contains('after'), 'after missing');
    end;

    [Test]
    procedure Update_MissingMapping_ReturnsError()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureInventoryItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('value', 'Red');
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Update", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Error');
    end;

    [Test]
    procedure Create_ServiceItem_Accepted()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        RequestJson: JsonObject;
        AttrArray: JsonArray;
        AttrObj: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Library.EnsureServiceItem(Item);
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);

        AttrObj.Add('name', ItemAttribute.Name);
        AttrObj.Add('value', 'Blue');
        AttrObj.Add('createValueIfMissing', true);
        AttrArray.Add(AttrObj);
        RequestJson.Add('attributes', AttrArray);

        ResponseJson := Library.ExecuteType(MessageType::"Item.Attribute.Create", Item."No.", RequestJson, true);
        Library.AssertStatus(ResponseJson, 'Success');
    end;

    [Test]
    procedure Enum_ValuesResolveToImpl()
    var
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
    begin
        MessageType := MessageType::"Item.Attribute.Get";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Get description');

        MessageType := MessageType::"Item.Attribute.Create";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Create description');

        MessageType := MessageType::"Item.Attribute.Update";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Update description');

        MessageType := MessageType::"Item.AttributeDefinition.Create";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Definition description');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_AttributeTables()
    var
        Argument: Record "Message Argument ori";
    begin
        Library.Initialize();
        Argument.Init();
        Argument.Insert(true);
        Assert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute"), '7500');
        Assert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute Value"), '7501');
        Assert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Item Attr. Value Translation"), '7504');
        Assert.IsTrue(Argument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute Value Mapping"), '7505');
        Assert.IsFalse(Argument.IsTableWriteRestrictedForDataRecords(Database::Item), 'Item 27 must not be restricted');
    end;
}
