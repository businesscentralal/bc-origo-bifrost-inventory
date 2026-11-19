namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Item.Create (#130): creates an item from an item template. Happy path, the base unit of measure
/// override edge case, refusals with their nextStep in en-US and is-IS, and the three-part type name.
/// Every test creates its own unit of measure, number series and item template.
/// </summary>
codeunit 96960 "Item Create Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Create_FromTemplate_ReturnsItemAndUnits()
    var
        Item: Record Item;
        TemplateCode: Code[20];
        UnitCode: Code[10];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        UnitJson: JsonObject;
        ItemNo: Code[20];
    begin
        // [SCENARIO AC01] templateCode with description, unit price and GTIN answers the new item no. with its units of measure.
        UnitCode := CreateUnit();
        TemplateCode := CreateTemplate(UnitCode);
        RequestJson.Add('templateCode', TemplateCode);
        RequestJson.Add('description', 'Office chair 130');
        RequestJson.Add('unitPrice', 129.5);
        RequestJson.Add('gtin', '5690000000017');
        ResponseJson := CallCreate(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        ItemNo := CopyStr(ReadText(ResponseJson, 'itemNo'), 1, MaxStrLen(ItemNo));
        Assert.AreNotEqual('', ItemNo, 'itemNo');
        Assert.IsTrue(Item.Get(ItemNo), 'the item exists');
        Assert.AreEqual('Office chair 130', Item.Description, 'description saved');
        Assert.AreEqual(129.5, Item."Unit Price", 'unit price saved');
        Assert.AreEqual('5690000000017', Item.GTIN, 'GTIN saved');
        Assert.AreEqual(UnitCode, Item."Base Unit of Measure", 'base unit from the template');
        Assert.AreEqual(Item."Costing Method"::Average, Item."Costing Method", 'costing method from the template');
        Assert.AreEqual(TemplateCode, ReadText(ResponseJson, 'templateCode'), 'templateCode answered');
        Assert.AreEqual(UnitCode, ReadText(ResponseJson, 'baseUnitOfMeasure'), 'baseUnitOfMeasure answered');
        Assert.AreEqual('5690000000017', ReadText(ResponseJson, 'gtin'), 'gtin answered');
        Assert.AreEqual(1, UnitCount(ResponseJson), 'one unit of measure');
        UnitJson := UnitAt(ResponseJson, 0);
        Assert.AreEqual(UnitCode, ReadText(UnitJson, 'code'), 'unit code');
        Assert.AreEqual(1, ReadDecimal(UnitJson, 'qtyPerUnitOfMeasure'), 'base unit holds one');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_OnlyTemplate_KeepsTemplateValues()
    var
        Item: Record Item;
        TemplateCode: Code[20];
        UnitCode: Code[10];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
    begin
        // [SCENARIO AC01 edge] Only templateCode creates an item with the template values and no GTIN.
        UnitCode := CreateUnit();
        TemplateCode := CreateTemplate(UnitCode);
        RequestJson.Add('templateCode', TemplateCode);
        ResponseJson := CallCreate(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        ItemNo := CopyStr(ReadText(ResponseJson, 'itemNo'), 1, MaxStrLen(ItemNo));
        Item.Get(ItemNo);
        Assert.AreEqual(UnitCode, Item."Base Unit of Measure", 'template base unit');
        Assert.AreEqual('', ReadText(ResponseJson, 'gtin'), 'no GTIN');
        Assert.AreEqual(0, ReadDecimal(ResponseJson, 'unitPrice'), 'no price');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_OtherBaseUnit_ReplacesTemplateUnit()
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        TemplateCode: Code[20];
        TemplateUnit: Code[10];
        OtherUnit: Code[10];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
    begin
        // [SCENARIO AC01 edge] baseUnitOfMeasure replaces the template unit; the answer lists the units the item has.
        TemplateUnit := CreateUnit();
        OtherUnit := CreateUnit();
        TemplateCode := CreateTemplate(TemplateUnit);
        RequestJson.Add('templateCode', TemplateCode);
        RequestJson.Add('baseUnitOfMeasure', OtherUnit);
        ResponseJson := CallCreate(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        ItemNo := CopyStr(ReadText(ResponseJson, 'itemNo'), 1, MaxStrLen(ItemNo));
        Item.Get(ItemNo);
        Assert.AreEqual(OtherUnit, Item."Base Unit of Measure", 'base unit replaced');
        Assert.AreEqual(OtherUnit, ReadText(ResponseJson, 'baseUnitOfMeasure'), 'baseUnitOfMeasure answered');
        Assert.IsTrue(ItemUnitOfMeasure.Get(ItemNo, OtherUnit), 'item unit of measure row for the new base unit');
        Assert.IsTrue(ContainsUnit(ResponseJson, OtherUnit), 'the answer lists the new base unit');
        ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
        Assert.AreEqual(ItemUnitOfMeasure.Count(), UnitCount(ResponseJson), 'the answer lists every unit of the item');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_UnknownTemplate_ReturnsRecordNotFound()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemCount: Integer;
    begin
        // [SCENARIO AC02] An unknown template answers RecordNotFound with a nextStep and creates nothing.
        ItemCount := Item.Count();
        RequestJson.Add('templateCode', 'T130-MISSING');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('templateCode', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Check the template code on the Item Templates page, or create the template there first.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(ItemCount, Item.Count(), 'no item created');
    end;

    [Test]
    procedure Create_UnknownBaseUnit_ReturnsInvalidParameter()
    var
        Item: Record Item;
        TemplateCode: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemCount: Integer;
    begin
        // [SCENARIO AC03] A base unit of measure that does not exist answers InvalidParameter and creates nothing.
        TemplateCode := CreateTemplate(CreateUnit());
        ItemCount := Item.Count();
        RequestJson.Add('templateCode', TemplateCode);
        RequestJson.Add('baseUnitOfMeasure', 'NOUNIT130');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('baseUnitOfMeasure', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('NOUNIT130', ReadText(ResponseJson, 'received'), 'received');
        Assert.AreEqual('Send the code of an existing unit of measure from the Units of Measure page, or leave baseUnitOfMeasure out to keep the template unit.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(ItemCount, Item.Count(), 'no item created');
    end;

    [Test]
    procedure Create_DomainOff_OnlyHidesType()
    var
        TempArgument: Record "Message Argument ori" temporary;
        CreateImpl: Codeunit "Item Create Impl ori";
        DomainCheck: Codeunit "Inv. MCP Fixture ori";
        RequestJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO Issue36 ruling 18.11.2026] Attributes off only hides the type; execution is not refused for the domain, also in is-IS at 1039.
        DisableAttributes();
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('templateCode', 'T130-MISSING');
        TempArgument.SetRequestJson(RequestJson);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        DomainCheck.AssertDomainOffOnlyHidesType(CreateImpl, TempArgument);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Create_MissingTemplate_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Without templateCode the call answers MissingParameter with a nextStep.
        RequestJson.Add('description', 'No template');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('templateCode', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send templateCode with the code of an item template. The Item Templates page lists them.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_EmptyTemplate_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An empty templateCode answers MissingParameter.
        RequestJson.Add('templateCode', '');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_UnitPriceAsText_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A wrong-typed key answers InvalidParameterFormat before the template is read.
        RequestJson.Add('templateCode', 'ANY');
        RequestJson.Add('unitPrice', '12.5');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('unitPrice', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send unitPrice as a number, for example 129.5.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_TemplateAsNumber_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] templateCode sent as a number answers InvalidParameterFormat.
        RequestJson.Add('templateCode', 130);
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send templateCode as text.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_NegativePrice_ReturnsInvalidParameter()
    var
        Item: Record Item;
        TemplateCode: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemCount: Integer;
    begin
        // [SCENARIO AC04] A unit price below zero answers InvalidParameter and creates nothing.
        TemplateCode := CreateTemplate(CreateUnit());
        ItemCount := Item.Count();
        RequestJson.Add('templateCode', TemplateCode);
        RequestJson.Add('unitPrice', -1);
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send unitPrice as zero or more.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        Assert.AreEqual(ItemCount, Item.Count(), 'no item created');
    end;

    [Test]
    procedure Create_GtinTooLong_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A GTIN longer than 14 characters answers InvalidParameter with the maximum length.
        RequestJson.Add('templateCode', 'ANY');
        RequestJson.Add('gtin', '123456789012345');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('gtin', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send gtin with at most 14 characters.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Create_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A key the type does not read answers UnknownParameter.
        RequestJson.Add('templateCode', 'ANY');
        RequestJson.Add('itemNo', '1000');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('itemNo', ReadText(ResponseJson, 'parameter'), 'parameter');
        // Foundation 28.0.10 and later refuses unknown keys on non-read types before Inventory runs (core#1160)
        // with its own shared nextStep; older Foundation reaches this type's own refusal.
        if FoundationRefusesUnknownWriteKeys() then
            Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep')
        else
            Assert.AreEqual('Remove the unknown key. Allowed keys are templateCode, description, baseUnitOfMeasure, unitPrice and gtin.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    local procedure FoundationRefusesUnknownWriteKeys(): Boolean
    var
        Info: ModuleInfo;
    begin
        if not NavApp.GetModuleInfo('7505e808-6e52-4b96-a328-82573391297a', Info) then
            Error('Bifrost Foundation is not installed.');
        exit(Info.AppVersion >= Version.Create(28, 0, 10, 0));
    end;

    [Test]
    procedure TypeName_HasThreeParts()
    var
        MessageType: Enum "Message Type ori";
        Parts: List of [Text];
    begin
        // [SCENARIO AC05] The type name has exactly three dot-separated parts.
        MessageType := MessageType::"Inventory.Item.Create";
        Parts := Format(MessageType).Split('.');
        Assert.AreEqual(3, Parts.Count(), 'three parts');
        Assert.AreEqual('Inventory.Item.Create', Format(MessageType), 'name');
    end;

    [Test]
    procedure Contract_DeclaresWriteEffect()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Token: JsonToken;
        Effect: JsonObject;
    begin
        // [SCENARIO core#1365 D1] The contract declares its real effect: a write that does not post and is not idempotent.
        ContractMgt.GetContract("Message Type ori"::"Inventory.Item.Create", Contract);
        Assert.IsTrue(Contract.Get('effect', Token), 'effect chapter');
        Effect := Token.AsObject();
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'effect');
        Effect.Get('posts', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'does not post');
        Effect.Get('idempotent', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'each call creates a new item');
    end;

    local procedure CallCreate(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        EnableAttributes();
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.Item.Create", '', RequestJson, true);
    end;

    local procedure EnableAttributes()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Attributes then
            exit;
        InventorySetup.Validate(Attributes, true);
        InventorySetup.Modify(true);
    end;

    local procedure DisableAttributes()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        InventorySetup.InsertIfNotExists();
        InventorySetup.Get();
        InventorySetup.Attributes := false;
        InventorySetup.Modify(true);
    end;

    local procedure CreateUnit() UnitCode: Code[10]
    var
        UnitOfMeasure: Record "Unit of Measure";
    begin
        UnitCode := CopyStr('U' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(UnitCode));
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := UnitCode;
        UnitOfMeasure.Description := 'Bifrost #130 test unit';
        UnitOfMeasure.Insert(true);
    end;

    local procedure CreateTemplate(UnitCode: Code[10]) TemplateCode: Code[20]
    var
        ItemTempl: Record "Item Templ.";
    begin
        TemplateCode := CopyStr('T' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(TemplateCode));
        ItemTempl.Init();
        ItemTempl.Code := TemplateCode;
        ItemTempl.Description := 'Bifrost #130 test template';
        ItemTempl."Base Unit of Measure" := UnitCode;
        ItemTempl."Costing Method" := ItemTempl."Costing Method"::Average;
        ItemTempl."No. Series" := CreateNoSeries();
        ItemTempl.Insert(true);
    end;

    local procedure CreateNoSeries() SeriesCode: Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        Prefix: Text;
    begin
        Prefix := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 8);
        SeriesCode := CopyStr('S' + Prefix, 1, MaxStrLen(SeriesCode));
        NoSeries.Init();
        NoSeries.Code := SeriesCode;
        NoSeries.Description := 'Bifrost #130 test items';
        NoSeries."Default Nos." := true;
        NoSeries.Insert(true);
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := SeriesCode;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine.Validate("Starting No.", CopyStr('I' + Prefix + '0001', 1, MaxStrLen(NoSeriesLine."Starting No.")));
        NoSeriesLine.Insert(true);
    end;

    local procedure DeleteItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        if Item.Get(ItemNo) then
            Item.Delete(true);
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual(Expected, ReadText(ResponseJson, 'status'), ResponseText);
    end;

    local procedure UnitCount(ResponseJson: JsonObject): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('unitsOfMeasure', Token), 'unitsOfMeasure');
        exit(Token.AsArray().Count());
    end;

    local procedure UnitAt(ResponseJson: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('unitsOfMeasure', Token), 'unitsOfMeasure');
        Token.AsArray().Get(Index, Token);
        exit(Token.AsObject());
    end;

    local procedure ContainsUnit(ResponseJson: JsonObject; UnitCode: Code[10]): Boolean
    var
        Token: JsonToken;
        UnitToken: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('unitsOfMeasure', Token), 'unitsOfMeasure');
        foreach UnitToken in Token.AsArray() do
            if ReadText(UnitToken.AsObject(), 'code') = UnitCode then
                exit(true);
        exit(false);
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            if not Token.AsValue().IsNull() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadDecimal(ResponseJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsDecimal());
        exit(-1);
    end;
}
