namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemCategory.Get and Inventory.ItemCategory.Set.
/// </summary>
codeunit 96928 "Item Category Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Get_ByCode_ReturnsCategoryAndInheritedAttribute()
    var
        ItemCategory: Record "Item Category";
        ParentCode: Code[20];
        ChildCode: Code[20];
        ResponseJson: JsonObject;
        CategoryJson: JsonObject;
        AttributeJson: JsonObject;
    begin
        ParentCode := CreateCategory('');
        ChildCode := CreateCategory(ParentCode);
        AssignColor(ParentCode, 'Blue');
        ResponseJson := CallGet(ChildCode, true);
        AssertStatus(ResponseJson, 'Success');
        CategoryJson := CategoryAt(ResponseJson, 0);
        ItemCategory.Get(ChildCode);
        Assert.AreEqual(ChildCode, ReadText(CategoryJson, 'code'), 'code');
        Assert.AreEqual(ParentCode, ReadText(CategoryJson, 'parentCategory'), 'parent');
        Assert.AreEqual(ItemCategory.Indentation, ReadInteger(CategoryJson, 'indentation'), 'indentation');
        Assert.AreEqual(ItemCategory."Presentation Order", ReadInteger(CategoryJson, 'presentationOrder'), 'order');
        AttributeJson := AttributeAt(CategoryJson, 0);
        Assert.AreEqual('Blue', ReadText(AttributeJson, 'value'), 'value');
        Assert.IsTrue(ReadBoolean(AttributeJson, 'inherited'), 'inherited');
        DeleteCategory(ChildCode);
        DeleteCategory(ParentCode);
    end;

    [Test]
    procedure Get_WithoutAttributes_OmitsAttributeArray()
    var
        CategoryCode: Code[20];
        ResponseJson: JsonObject;
        CategoryJson: JsonObject;
    begin
        CategoryCode := CreateCategory('');
        ResponseJson := CallGet(CategoryCode, false);
        AssertStatus(ResponseJson, 'Success');
        CategoryJson := CategoryAt(ResponseJson, 0);
        Assert.IsFalse(CategoryJson.Contains('attributes'), 'attributes should be omitted');
        DeleteCategory(CategoryCode);
    end;

    [Test]
    procedure Get_MissingCategory_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson := CallGet('IC111-MISSING', true);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Check the category code.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Set_CreatesCategoryAndLocalAttribute()
    var
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        Library: Codeunit "Inventory Test Library ori";
        CategoryCode: Code[20];
        ResponseJson: JsonObject;
        AttributeJson: JsonObject;
        Attributes: JsonArray;
    begin
        EnableItemCategory();
        Library.Initialize();
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        CategoryCode := NewCode();
        Attributes.Add(AttributeEntry(ItemAttribute.ID, 'Blue'));
        ResponseJson := CallSet(CategoryRequest(CategoryCode, 'Chairs', '', Attributes));
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual('Chairs', ReadText(ResponseJson, 'description'), 'description');
        AttributeJson := AttributeAt(ResponseJson, 0);
        Assert.AreEqual('Blue', ReadText(AttributeJson, 'value'), 'value');
        Assert.IsFalse(ReadBoolean(AttributeJson, 'inherited'), 'local value is not inherited');
        Assert.IsTrue(Mapping.Get(Database::"Item Category", CategoryCode, ItemAttribute.ID), 'mapping');
        DeleteCategory(CategoryCode);
    end;

    [Test]
    procedure Set_ValueEqualToParent_AnswersInherited()
    var
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        Library: Codeunit "Inventory Test Library ori";
        ParentCode: Code[20];
        ChildCode: Code[20];
        ResponseJson: JsonObject;
        AttributeJson: JsonObject;
        Attributes: JsonArray;
    begin
        EnableItemCategory();
        Library.Initialize();
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        ParentCode := NewCode();
        Attributes.Add(AttributeByName(ItemAttribute.Name, 'Blue'));
        ResponseJson := CallSet(CategoryRequest(ParentCode, 'Parent', '', Attributes));
        AssertStatus(ResponseJson, 'Success');
        ChildCode := NewCode();
        Clear(Attributes);
        Attributes.Add(AttributeByName(ItemAttribute.Name, 'Blue'));
        ResponseJson := CallSet(CategoryRequest(ChildCode, 'Child', ParentCode, Attributes));
        AssertStatus(ResponseJson, 'Success');
        AttributeJson := AttributeAt(ResponseJson, 0);
        Assert.IsTrue(ReadBoolean(AttributeJson, 'inherited'), 'inherited');
        Assert.IsFalse(Mapping.Get(Database::"Item Category", ChildCode, ItemAttribute.ID), 'child keeps no local row');
        DeleteCategory(ChildCode);
        DeleteCategory(ParentCode);
    end;

    [Test]
    procedure Set_ParentLoop_ReturnsInvalidParameter()
    var
        ItemCategory: Record "Item Category";
        ParentCode: Code[20];
        ChildCode: Code[20];
        ResponseJson: JsonObject;
    begin
        ParentCode := CreateCategory('');
        ChildCode := CreateCategory(ParentCode);
        ResponseJson := CallSet(CategoryRequest(ParentCode, '', ChildCode, EmptyAttributes()));
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Choose a parent outside this category''s subtree.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemCategory.Get(ParentCode);
        Assert.AreEqual('', ItemCategory."Parent Category", 'parent unchanged');
        DeleteCategory(ChildCode);
        DeleteCategory(ParentCode);
    end;

    [Test]
    procedure Set_Reparent_ReturnsPreconditionFailed()
    var
        ItemCategory: Record "Item Category";
        LeftCode: Code[20];
        RightCode: Code[20];
        ResponseJson: JsonObject;
    begin
        LeftCode := CreateCategory('');
        RightCode := CreateCategory('');
        ResponseJson := CallSet(CategoryRequest(LeftCode, '', RightCode, EmptyAttributes()));
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use the BC page for deletes.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemCategory.Get(LeftCode);
        Assert.AreEqual('', ItemCategory."Parent Category", 'parent unchanged');
        DeleteCategory(LeftCode);
        DeleteCategory(RightCode);
    end;

    [Test]
    procedure Set_Delete_ReturnsPreconditionFailed()
    var
        ResponseJson: JsonObject;
        RequestJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('code', NewCode());
        RequestJson.Add('delete', true);
        ResponseJson := CallSet(RequestJson);
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Use the BC page for deletes.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Set_MissingAttribute_ReturnsRecordNotFound()
    var
        ItemCategory: Record "Item Category";
        CategoryCode: Code[20];
        ResponseJson: JsonObject;
        Attributes: JsonArray;
    begin
        EnableItemCategory();
        CategoryCode := NewCode();
        Attributes.Add(AttributeByName('NO-SUCH-IC111', 'Blue'));
        ResponseJson := CallSet(CategoryRequest(CategoryCode, 'Missing', '', Attributes));
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Create the attribute with Inventory.AttributeDefinition.Create first.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.IsFalse(ItemCategory.Get(CategoryCode), 'nothing was written');
    end;

    [Test]
    procedure Set_MissingValue_ReturnsRecordNotFound()
    var
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        ItemCategory: Record "Item Category";
        Library: Codeunit "Inventory Test Library ori";
        CategoryCode: Code[20];
        ResponseJson: JsonObject;
        Attributes: JsonArray;
    begin
        EnableItemCategory();
        Library.Initialize();
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        CategoryCode := NewCode();
        Attributes.Add(AttributeEntry(ItemAttribute.ID, 'NotARealValue'));
        ResponseJson := CallSet(CategoryRequest(CategoryCode, 'Missing value', '', Attributes));
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Create the attribute with Inventory.AttributeDefinition.Create first.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.IsFalse(ItemCategory.Get(CategoryCode), 'nothing was written');
    end;

    [Test]
    procedure Set_MissingCode_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('description', 'No code');
        ResponseJson := CallSet(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure Set_CodeAsNumber_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('code', 15);
        ResponseJson := CallSet(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure Set_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('code', NewCode());
        RequestJson.Add('nope', 'x');
        ResponseJson := CallSet(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure Set_CodeAndSystemId_ReturnsConflict()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('code', NewCode());
        RequestJson.Add('systemId', '00000000-0000-0000-0000-000000000001');
        ResponseJson := CallSet(RequestJson);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_ItemCategory()
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        TempArgument.Init();
        TempArgument.Insert(true);
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Category", false), '5722');
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Attribute Value Mapping", false), '7505');
    end;

    local procedure CreateCategory(ParentCode: Code[20]) CategoryCode: Code[20]
    var
        ResponseJson: JsonObject;
    begin
        EnableItemCategory();
        CategoryCode := NewCode();
        ResponseJson := CallSet(CategoryRequest(CategoryCode, CategoryCode, ParentCode, EmptyAttributes()));
        AssertStatus(ResponseJson, 'Success');
    end;

    local procedure AssignColor(CategoryCode: Code[20]; ValueText: Text)
    var
        ItemAttribute: Record "Item Attribute";
        ValueA: Record "Item Attribute Value";
        ValueB: Record "Item Attribute Value";
        Library: Codeunit "Inventory Test Library ori";
        ResponseJson: JsonObject;
        Attributes: JsonArray;
    begin
        Library.Initialize();
        Library.CreateOptionAttribute('Color', ItemAttribute, ValueA, ValueB);
        Attributes.Add(AttributeEntry(ItemAttribute.ID, ValueText));
        ResponseJson := CallSet(CategoryRequest(CategoryCode, CategoryCode, '', Attributes));
        AssertStatus(ResponseJson, 'Success');
    end;

    local procedure CallGet(CategoryCode: Code[20]; IncludeAttributes: Boolean) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
        RequestJson: JsonObject;
    begin
        EnableItemCategory();
        RequestJson.Add('code', CategoryCode);
        RequestJson.Add('includeAttributes', IncludeAttributes);
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCategory.Get", CategoryCode, RequestJson, false);
    end;

    local procedure CallSet(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemCategory.Set", '', RequestJson, false);
    end;

    local procedure CategoryRequest(CategoryCode: Code[20]; Description: Text; ParentCode: Code[20]; Attributes: JsonArray) RequestJson: JsonObject
    begin
        RequestJson.Add('code', CategoryCode);
        if Description <> '' then
            RequestJson.Add('description', Description);
        if ParentCode <> '' then
            RequestJson.Add('parentCategory', ParentCode);
        if Attributes.Count() > 0 then
            RequestJson.Add('attributes', Attributes);
    end;

    local procedure AttributeEntry(AttributeId: Integer; ValueText: Text) AttributeJson: JsonObject
    begin
        AttributeJson.Add('id', AttributeId);
        AttributeJson.Add('value', ValueText);
    end;

    local procedure AttributeByName(AttributeName: Text; ValueText: Text) AttributeJson: JsonObject
    begin
        AttributeJson.Add('name', AttributeName);
        AttributeJson.Add('value', ValueText);
    end;

    local procedure EmptyAttributes(): JsonArray
    begin
    end;

    local procedure EnableItemCategory()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup."Item Category" then
            exit;
        InventorySetup.Validate("Item Category", true);
        InventorySetup.Modify(true);
    end;

    local procedure NewCode() CategoryCode: Code[20]
    begin
        CategoryCode := CopyStr('IC' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(CategoryCode));
    end;

    local procedure DeleteCategory(CategoryCode: Code[20])
    var
        ItemCategory: Record "Item Category";
    begin
        if ItemCategory.Get(CategoryCode) then
            ItemCategory.Delete(true);
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    begin
        Assert.AreEqual(Expected, ReadText(ResponseJson, 'status'), 'status');
    end;

    local procedure CategoryAt(ResponseJson: JsonObject; Index: Integer) CategoryJson: JsonObject
    var
        Token: JsonToken;
        Categories: JsonArray;
    begin
        Assert.IsTrue(ResponseJson.Get('categories', Token), 'categories');
        Categories := Token.AsArray();
        Categories.Get(Index, Token);
        CategoryJson := Token.AsObject();
    end;

    local procedure AttributeAt(CategoryJson: JsonObject; Index: Integer) AttributeJson: JsonObject
    var
        Token: JsonToken;
        Attributes: JsonArray;
    begin
        Assert.IsTrue(CategoryJson.Get('attributes', Token), 'attributes');
        Attributes := Token.AsArray();
        Attributes.Get(Index, Token);
        AttributeJson := Token.AsObject();
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadInteger(ResponseJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsInteger());
        exit(-1);
    end;

    local procedure ReadBoolean(ResponseJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
