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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Get", Item."No.", RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('items', ItemsToken), 'items missing');
        ItemsArray := ItemsToken.AsArray();
        Assert.IsTrue(ItemsArray.Count() > 0, 'expected at least one item');
    end;

    [Test]
    procedure Get_EmptyFilter_ReturnsRecordNotFound_1033()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OldLanguage: Integer;
    begin
        Item.SetRange("No.", 'ZZW8148-NO-ITEM');
        Assert.IsTrue(Item.IsEmpty(), 'The selected fixture range is empty.');
        Request.Add('tableView', Item.GetView(true));
        OldLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Attribute.Get", '', Request, false);
        GlobalLanguage(OldLanguage);
        Library.AssertStatus(Response, 'Error');
        Assert.IsTrue(Response.Get('code', Token), 'The Foundation range resolver supplies a code.');
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'The empty range uses the declared Foundation lookup refusal.');
    end;

    [Test]
    procedure Get_EmptyFilter_ReturnsRecordNotFound_1039()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        OldLanguage: Integer;
    begin
        Item.SetRange("No.", 'ZZW8148-NO-ITEM');
        Assert.IsTrue(Item.IsEmpty(), 'The selected fixture range is empty.');
        Request.Add('tableView', Item.GetView(true));
        OldLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.Attribute.Get", '', Request, false);
        GlobalLanguage(OldLanguage);
        Library.AssertStatus(Response, 'Error');
        Assert.IsTrue(Response.Get('code', Token), 'The Foundation range resolver supplies a code.');
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'The empty range uses the declared Foundation lookup refusal.');
    end;

    [Test]
    procedure Get_MissingItem_ReturnsError()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Get", 'NO-SUCH-ITEM-ZZZ', RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Create", Item."No.", RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Create", Item."No.", RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Create", Item."No.", RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Create", Item."No.", RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Update", Item."No.", RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Update", Item."No.", RequestJson, false);
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

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.Attribute.Create", Item."No.", RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
    end;

    [Test]
    procedure Enum_ValuesResolveToImpl()
    var
        MessageType: Enum "Message Type ori";
        MsgInterface: Interface "Msg Interface ori";
    begin
        MessageType := MessageType::"Inventory.Attribute.Get";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Get description');

        MessageType := MessageType::"Inventory.Attribute.Create";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Create description');

        MessageType := MessageType::"Inventory.Attribute.Update";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Update description');

        MessageType := MessageType::"Inventory.AttributeDefinition.Create";
        MsgInterface := MessageType;
        Assert.AreNotEqual('', MsgInterface.GetDescription(), 'Definition description');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_AttributeTables()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        Library.Initialize();
        TempArgument.Init();
        TempArgument.Insert(true);
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute", false), '7500');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute Value", false), '7501');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Attr. Value Translation", false), '7504');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute Value Mapping", false), '7505');
        Assert.IsFalse(TempArgument.IsTableWriteRestrictedForDataRecords(Database::Item, false), 'Item 27 must not be restricted');
    end;
    /// <summary>Invalid attribute arrays return the coded issue148 refusal declared by help.</summary>
    [Test]
    procedure Create_InvalidAttributes_MatchesHelpCode()
    begin
        AssertInvalidAttributes("Message Type ori"::"Inventory.Attribute.Create");
    end;

    /// <summary>Update documents InvalidLine for missing, empty and non-array attributes.</summary>
    [Test]
    procedure Update_InvalidAttributes_MatchesHelpCode()
    begin
        AssertInvalidAttributes("Message Type ori"::"Inventory.Attribute.Update");
    end;

    local procedure AssertInvalidAttributes(MessageType: Enum "Message Type ori")
    var
        Item: Record Item;
        InventorySetup: Record "Inventory Setup ori";
        Helper: Codeunit "Assembly Order Test Helper";
        Contract: Interface "Msg Contract ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Attributes: JsonArray;
        Errors: JsonArray;
        Entry: JsonToken;
        Token: JsonToken;
        LanguageId: Integer;
        PreviousLanguage: Integer;
        Scenario: Integer;
        Found: Boolean;
        AttributesEnabled: Boolean;
    begin
        Library.Initialize();
        InventorySetup.InsertIfNotExists();
        AttributesEnabled := InventorySetup.Attributes;
        InventorySetup.Attributes := true;
        InventorySetup.Modify(true);
        Item.Init();
        Item."No." := CopyStr('ZZ152' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Item."No."));
        Item.Description := 'Inventory attribute refusal test';
        Item.Insert(true);
        // Story148 AC01 supersedes the older help-only175 BusinessCentralError expectation.
        Contract := MessageType;
        Contract.GetErrors(Errors);
        foreach Entry in Errors do
            if Entry.AsObject().Get('when', Token) then
                if Token.AsValue().AsText() = 'attributes is absent, empty, not an array, or contains an entry that is not an object.' then begin
                    Found := true;
                    Assert.IsTrue(Entry.AsObject().Get('code', Token), 'Invalid array help needs a code.');
                    Assert.AreEqual('InvalidLine', Token.AsValue().AsText(), 'Issue148 help declares the coded validation refusal.');
                end;
        Assert.IsTrue(Found, 'Help must describe invalid attribute arrays.');
        PreviousLanguage := GlobalLanguage();
        for LanguageId := 1033 to 1039 do
            if LanguageId in [1033, 1039] then begin
                GlobalLanguage(LanguageId);
                for Scenario := 1 to 3 do begin
                    Clear(RequestJson);
                    case Scenario of
                        2:
                            RequestJson.Add('attributes', Attributes);
                        3:
                            RequestJson.Add('attributes', 'not an array');
                    end;
                    Clear(ResponseJson);
                    // EnqueueAndProcess preserves the requested language; Execute uses the company default.
                    Helper.ProcessMessage(MessageType, Item."No.", RequestJson, ResponseJson);
                    Library.AssertStatus(ResponseJson, 'Error');
                    Assert.IsTrue(ResponseJson.Get('code', Token), 'Runtime error needs a code.');
                    Assert.AreEqual('InvalidLine', Token.AsValue().AsText(), 'Invalid array runtime code matches help.');
                    Assert.IsTrue(ResponseJson.Get('parameter', Token), 'Invalid array refusal names the parameter.');
                    Assert.AreEqual('attributes', Token.AsValue().AsText(), 'Invalid array parameter.');
                    Assert.IsTrue(ResponseJson.Get('expected', Token), 'Invalid array refusal states the expected shape.');
                    if LanguageId = 1033 then
                        Assert.AreEqual('a non-empty array of attribute objects', Token.AsValue().AsText(), 'English expected shape.')
                    else
                        Assert.AreEqual('fylki eigindahluta sem er ekki tómt', Token.AsValue().AsText(), 'Icelandic expected shape.');
                    Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'Invalid array refusal has a next step.');
                    if LanguageId = 1033 then
                        Assert.AreEqual('Send at least one attribute object in data.attributes.', Token.AsValue().AsText(), 'English next step.')
                    else
                        Assert.AreEqual('Sendu a.m.k. einn eigindahlut í data.attributes.', Token.AsValue().AsText(), 'Icelandic next step.');
                    Assert.IsTrue(ResponseJson.Get('error', Token), 'Runtime error needs text.');
                    if LanguageId = 1033 then
                        Assert.AreEqual('Request data.attributes must be a non-empty array.', Token.AsValue().AsText(), 'English refusal.')
                    else
                        Assert.AreEqual('data.attributes í beiðninni verður að vera fylki sem er ekki tómt.', Token.AsValue().AsText(), 'Icelandic refusal.');
                end;
            end;
        GlobalLanguage(PreviousLanguage);
        Item.Delete(true);
        InventorySetup.Get();
        InventorySetup.Attributes := AttributesEnabled;
        InventorySetup.Modify(true);
    end;

}
