namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.SKU.Create and Inventory.SKU.Get (#114): happy paths, replace option, refusals with a nextStep,
/// the Data.Records write restriction on Stockkeeping Unit and the en-US and is-IS help.
/// </summary>
codeunit 96968 "SKU Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ItemNoTok: Label 'SKU114-I1', Locked = true;
        LocationATok: Label 'SKU114A', Locked = true;
        LocationBTok: Label 'SKU114B', Locked = true;
        LocationFilterTok: Label 'SKU114A|SKU114B', Locked = true;

    [Test]
    procedure Create_PerLocation_MakesOneUnitPerLocation()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] Create answers the units made for the item and the locations in the filter.
        Seed();
        ResponseJson := CallCreate(CreateRequest(false, ''));
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(1, ReadInteger(ResponseJson, 'itemsMatched'), 'itemsMatched');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'created'), 'created');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'skuCount'), 'skuCount');
        Assert.IsTrue(SkuExists(LocationATok), 'unit at A');
        Assert.IsTrue(SkuExists(LocationBTok), 'unit at B');
        Cleanup();
    end;

    [Test]
    procedure Create_ExistingUnitKept_WithoutReplace()
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] Without replaceExisting a unit edited by hand keeps its values and is not counted as created.
        Seed();
        AssertStatus(CallCreate(CreateRequest(false, '')), 'Success');
        StockkeepingUnit.Get(ItemNoTok, LocationATok, '');
        StockkeepingUnit."Reorder Point" := 7;
        StockkeepingUnit.Modify();
        ResponseJson := CallCreate(CreateRequest(false, ''));
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'created'), 'created');
        StockkeepingUnit.Get(ItemNoTok, LocationATok, '');
        Assert.AreEqual(7, StockkeepingUnit."Reorder Point", 'reorder point kept');
        Cleanup();
    end;

    [Test]
    procedure Create_ReplaceExisting_ResetsUnitFromItemCard()
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] replaceExisting true rebuilds the unit from the item card.
        Seed();
        AssertStatus(CallCreate(CreateRequest(false, '')), 'Success');
        StockkeepingUnit.Get(ItemNoTok, LocationATok, '');
        StockkeepingUnit."Reorder Point" := 7;
        StockkeepingUnit.Modify();
        ResponseJson := CallCreate(CreateRequest(true, ''));
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'skuCount'), 'skuCount');
        StockkeepingUnit.Get(ItemNoTok, LocationATok, '');
        Assert.AreEqual(0, StockkeepingUnit."Reorder Point", 'reorder point reset');
        Cleanup();
    end;

    [Test]
    procedure Create_MissingItemFilter_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A call without itemFilter is refused with a nextStep.
        RequestJson.Add('createPer', 'Location');
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'MissingParameter');
    end;

    [Test]
    procedure Create_InvalidCreatePer_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] createPer outside the three methods is refused with a nextStep.
        RequestJson.Add('itemFilter', ItemNoTok);
        RequestJson.Add('createPer', 'Warehouse');
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'InvalidParameter');
    end;

    [Test]
    procedure Create_ItemFilterNotText_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A number where text is expected is refused with a nextStep.
        RequestJson.Add('itemFilter', 5);
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Create_ReplaceExistingNotBoolean_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] replaceExisting as text is refused with a nextStep.
        RequestJson.Add('itemFilter', ItemNoTok);
        RequestJson.Add('replaceExisting', 'yes');
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Create_NoMatchingItem_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A filter that matches no item is refused and nothing is made.
        RequestJson.Add('itemFilter', 'SKU114-NONE');
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'RecordNotFound');
    end;

    [Test]
    procedure Create_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A key the type does not read is refused with a nextStep.
        RequestJson.Add('itemFilter', ItemNoTok);
        RequestJson.Add('bogus', true);
        ResponseJson := CallCreate(RequestJson);
        AssertRefusal(ResponseJson, 'UnknownParameter');
    end;

    [Test]
    procedure Get_ReturnsPlanningAndCostFields()
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        SkuJson: JsonObject;
    begin
        // [SCENARIO AC02] Get answers a unit with its planning and cost fields.
        Seed();
        AssertStatus(CallCreate(CreateRequest(false, '')), 'Success');
        StockkeepingUnit.Get(ItemNoTok, LocationATok, '');
        StockkeepingUnit."Reorder Point" := 12;
        StockkeepingUnit."Reorder Quantity" := 30;
        StockkeepingUnit."Unit Cost" := 4.5;
        StockkeepingUnit."Standard Cost" := 5;
        StockkeepingUnit.Modify();
        RequestJson.Add('itemNo', ItemNoTok);
        RequestJson.Add('locationCode', LocationATok);
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(1, ReadInteger(ResponseJson, 'count'), 'count');
        SkuJson := SkuAt(ResponseJson, 0);
        Assert.AreEqual(ItemNoTok, ReadText(SkuJson, 'itemNo'), 'itemNo');
        Assert.AreEqual(LocationATok, ReadText(SkuJson, 'locationCode'), 'locationCode');
        Assert.AreEqual(12, ReadDecimal(SkuJson, 'reorderPoint'), 'reorderPoint');
        Assert.AreEqual(30, ReadDecimal(SkuJson, 'reorderQuantity'), 'reorderQuantity');
        Assert.AreEqual(4.5, ReadDecimal(SkuJson, 'unitCost'), 'unitCost');
        Assert.AreEqual(5, ReadDecimal(SkuJson, 'standardCost'), 'standardCost');
        Cleanup();
    end;

    [Test]
    procedure Get_EmptyLocationCode_SelectsUnitsWithoutLocation()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC02] An empty locationCode selects units with a blank location only; units per location are left out.
        Seed();
        AssertStatus(CallCreate(CreateRequest(false, '')), 'Success');
        RequestJson.Add('itemNo', ItemNoTok);
        RequestJson.Add('locationCode', '');
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(0, ReadInteger(ResponseJson, 'count'), 'no unit without location');
        Clear(RequestJson);
        RequestJson.Add('itemNo', ItemNoTok);
        ResponseJson := CallGet(RequestJson);
        Assert.AreEqual(2, ReadInteger(ResponseJson, 'count'), 'both locations when locationCode is omitted');
        Cleanup();
    end;

    [Test]
    procedure Get_LocationCodeNotText_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A wrong-typed key is refused with a nextStep.
        RequestJson.Add('locationCode', true);
        ResponseJson := CallGet(RequestJson);
        AssertRefusal(ResponseJson, 'InvalidParameterFormat');
    end;

    [Test]
    procedure Get_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An unknown key is refused with a nextStep.
        RequestJson.Add('bogus', 'x');
        ResponseJson := CallGet(RequestJson);
        AssertRefusal(ResponseJson, 'UnknownParameter');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_StockkeepingUnit()
    var
        TempArgument: Record "Message Argument ori" temporary;
        ErrorText: Text;
    begin
        // [SCENARIO AC03] Data.Records.Set is refused on table 5700, names the dedicated types, and reads stay allowed.
        TempArgument.Init();
        TempArgument.Insert(true);
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Stockkeeping Unit", false), '5700 write restricted');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Stockkeeping Unit"), '5700 reads stay allowed');
        Assert.AreEqual('Inventory.SKU.Create / Inventory.SKU.Get', TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Stockkeeping Unit"), '5700 hint');
        ErrorText := TempArgument.GetRestrictedTableErrorText(Database::"Stockkeeping Unit", 'Blocked.', true);
        Assert.AreNotEqual(0, StrPos(ErrorText, 'Inventory.SKU.Create'), ErrorText);
    end;

    [Test]
    procedure Help_IsTranslatedToIcelandic()
    var
        CreateImpl: Codeunit "SKU Create Impl ori";
        GetImpl: Codeunit "SKU Get Impl ori";
        PreviousLanguage: Integer;
        Overview: Text;
        English: Text;
    begin
        // [SCENARIO AC04] Help answers in en-US and is-IS.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        CreateImpl.GetOverview(English);
        Assert.AreNotEqual(0, StrPos(English, 'Creates stockkeeping units'), English);
        GlobalLanguage(1039);
        CreateImpl.GetOverview(Overview);
        Assert.AreNotEqual(0, StrPos(Overview, 'birgðageymsluvörur'), Overview);
        GetImpl.GetOverview(Overview);
        Assert.AreNotEqual(0, StrPos(Overview, 'birgðageymsluvörur'), Overview);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure MessageTypeNames_HaveThreeParts()
    begin
        // [SCENARIO AC05] Both names have exactly three dot-separated parts.
        Assert.AreEqual(3, StrLen(Format("Message Type ori"::"Inventory.SKU.Create")) - StrLen(DelChr(Format("Message Type ori"::"Inventory.SKU.Create"), '=', '.')) + 1, 'Create');
        Assert.AreEqual(3, StrLen(Format("Message Type ori"::"Inventory.SKU.Get")) - StrLen(DelChr(Format("Message Type ori"::"Inventory.SKU.Get"), '=', '.')) + 1, 'Get');
    end;

    local procedure Seed()
    var
        Item: Record Item;
        Location: Record Location;
    begin
        Cleanup();
        Item.Init();
        Item."No." := ItemNoTok;
        Item.Insert();
        Location.Init();
        Location.Code := LocationATok;
        Location.Insert();
        Location.Code := LocationBTok;
        Location.Insert();
    end;

    local procedure Cleanup()
    var
        Item: Record Item;
        Location: Record Location;
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        StockkeepingUnit.SetRange("Item No.", ItemNoTok);
        StockkeepingUnit.DeleteAll();
        if Item.Get(ItemNoTok) then
            Item.Delete();
        Location.SetFilter(Code, LocationFilterTok);
        Location.DeleteAll();
    end;

    local procedure CreateRequest(ReplaceExisting: Boolean; CreatePer: Text) RequestJson: JsonObject
    begin
        RequestJson.Add('itemFilter', ItemNoTok);
        RequestJson.Add('locationFilter', LocationFilterTok);
        RequestJson.Add('itemInInventoryOnly', false);
        RequestJson.Add('replaceExisting', ReplaceExisting);
        if CreatePer <> '' then
            RequestJson.Add('createPer', CreatePer);
    end;

    local procedure CallCreate(RequestJson: JsonObject): JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        exit(Library.ExecuteType("Message Type ori"::"Inventory.SKU.Create", '', RequestJson, false));
    end;

    local procedure CallGet(RequestJson: JsonObject): JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        exit(Library.ExecuteType("Message Type ori"::"Inventory.SKU.Get", '', RequestJson, false));
    end;

    local procedure SkuExists(LocationCode: Code[10]): Boolean
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        exit(StockkeepingUnit.Get(ItemNoTok, LocationCode, ''));
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    begin
        Assert.AreEqual(Expected, ReadText(ResponseJson, 'status'), 'status; response code=' + ReadText(ResponseJson, 'code') + ' ' + ReadText(ResponseJson, 'message'));
    end;

    local procedure AssertRefusal(ResponseJson: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual(ExpectedCode, ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    local procedure SkuAt(ResponseJson: JsonObject; Index: Integer): JsonObject
    var
        Token: JsonToken;
        ItemToken: JsonToken;
    begin
        ResponseJson.Get('skus', Token);
        Token.AsArray().Get(Index, ItemToken);
        exit(ItemToken.AsObject());
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

    local procedure ReadDecimal(ResponseJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsDecimal());
        exit(-1);
    end;
}
