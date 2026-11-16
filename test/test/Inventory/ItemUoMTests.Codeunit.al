namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemUnitOfMeasure.Create and Inventory.ItemUnitOfMeasure.Get (#100): happy paths, base unit flag,
/// coded refusals with a nextStep in both languages, the ledger-entry refusal and the three-part name rule.
/// </summary>
codeunit 96984 "Item UoM Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Create_NewUnit_SavesQtyDimensionsAndWeight()
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        UnitJson: JsonObject;
    begin
        // [SCENARIO AC01] Create takes item no., code, qty. per unit of measure, dimensions and weight.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        RequestJson := CreateRequest(ItemNo, 'UOMBOX', 6);
        RequestJson.Add('length', 30);
        RequestJson.Add('width', 20);
        RequestJson.Add('height', 10);
        RequestJson.Add('weight', 2.5);
        ResponseJson := CallCreate(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'created'), 'created');
        UnitJson := ReadObject(ResponseJson, 'unit');
        Assert.AreEqual('UOMBOX', ReadText(UnitJson, 'code'), 'code');
        Assert.AreEqual(6, ReadDecimal(UnitJson, 'qtyPerUnitOfMeasure'), 'qty');
        Assert.IsFalse(ReadBoolean(UnitJson, 'isBaseUnit'), 'not base');
        Assert.IsTrue(ItemUnitOfMeasure.Get(ItemNo, 'UOMBOX'), 'saved');
        Assert.AreEqual(6, ItemUnitOfMeasure."Qty. per Unit of Measure", 'saved qty');
        Assert.AreEqual(30, ItemUnitOfMeasure.Length, 'saved length');
        Assert.AreEqual(20, ItemUnitOfMeasure.Width, 'saved width');
        Assert.AreEqual(10, ItemUnitOfMeasure.Height, 'saved height');
        Assert.AreEqual(2.5, ItemUnitOfMeasure.Weight, 'saved weight');
        Assert.AreEqual(ItemUnitOfMeasure.Cubage, ReadDecimal(UnitJson, 'cubage'), 'cubage answered');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_FlagsBaseUnit()
    var
        Item: Record Item;
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Units: JsonArray;
        Token: JsonToken;
    begin
        // [SCENARIO AC02] Get answers the units with the base unit flagged.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        EnsureUnit('UOMPCS');
        AddBaseUnit(ItemNo, 'UOMPCS');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'UOMBOX', 12)), 'Success');
        RequestJson.Add('itemNo', ItemNo);
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual('UOMPCS', ReadText(ResponseJson, 'baseUnitOfMeasure'), 'base unit');
        Assert.IsTrue(ResponseJson.Get('units', Token), 'units');
        Units := Token.AsArray();
        Assert.AreEqual(2, Units.Count(), 'two units');
        Units.Get(0, Token);
        Assert.AreEqual('UOMBOX', ReadText(Token.AsObject(), 'code'), 'first in code order');
        Assert.IsFalse(ReadBoolean(Token.AsObject(), 'isBaseUnit'), 'box is not base');
        Units.Get(1, Token);
        Assert.AreEqual('UOMPCS', ReadText(Token.AsObject(), 'code'), 'second');
        Assert.IsTrue(ReadBoolean(Token.AsObject(), 'isBaseUnit'), 'pcs is base');
        Assert.IsTrue(Item.Get(ItemNo), 'item');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_ItemAndCode_AnswersOneUnit()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO AC02] code narrows the answer to one unit.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        EnsureUnit('UOMPCS');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'UOMBOX', 12)), 'Success');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'UOMPCS', 1)), 'Success');
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'uombox');
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('units', Token), 'units');
        Assert.AreEqual(1, Token.AsArray().Count(), 'one unit');
        Token.AsArray().Get(0, Token);
        Assert.AreEqual('UOMBOX', ReadText(Token.AsObject(), 'code'), 'code');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_ItemWithoutUnits_AnswersEmptyArray()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO AC02 edge] An item without units answers Success with an empty array.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('units', Token), 'units');
        Assert.AreEqual(0, Token.AsArray().Count(), 'no units');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_ExistingUnitWithLedgerEntries_ReturnsPreconditionFailed()
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC03] A unit that item ledger entries use is not changed: the call is refused with PreconditionFailed.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'UOMBOX', 6)), 'Success');
        InsertLedgerEntry(ItemNo, 'UOMBOX');
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'UOMBOX', 8));
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'error'), 'item ledger entries'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Choose another unit of measure code, or read the existing unit with Inventory.ItemUnitOfMeasure.Get.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemUnitOfMeasure.Get(ItemNo, 'UOMBOX');
        Assert.AreEqual(6, ItemUnitOfMeasure."Qty. per Unit of Measure", 'qty is unchanged');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_ExistingUnitWithoutEntries_ReturnsPreconditionFailed()
    var
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04 edge] A second Create with the same code is refused and the first unit is unchanged.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'UOMBOX', 6)), 'Success');
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'UOMBOX', 8));
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual(0, StrPos(ReadText(ResponseJson, 'error'), 'item ledger entries'), 'no ledger wording');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_UnknownItem_ReturnsRecordNotFound()
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An item that does not exist answers RecordNotFound with a nextStep; nothing is saved.
        EnsureUnit('UOMBOX');
        ResponseJson := CallCreate(CreateRequest('UOM100-MISSING', 'UOMBOX', 6));
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('itemNo', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Check the item number. The item must exist before a unit of measure can be created on it.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemUnitOfMeasure.SetRange("Item No.", 'UOM100-MISSING');
        Assert.RecordIsEmpty(ItemUnitOfMeasure);
    end;

    [Test]
    procedure Create_UndefinedUnitCode_ReturnsRecordNotFound()
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A code that is not a unit of measure in Business Central answers RecordNotFound on code.
        ItemNo := CreateItem();
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'NOSUCHUOM', 6));
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(ItemUnitOfMeasure);
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_MissingQty_ReturnsMissingParameter()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A missing qtyPerUnitOfMeasure answers MissingParameter with a nextStep.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'UOMBOX');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('qtyPerUnitOfMeasure', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send qtyPerUnitOfMeasure as a JSON number greater than 0.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_ZeroQty_ReturnsInvalidParameter()
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A quantity that is not greater than 0 answers InvalidParameter; nothing is saved.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'UOMBOX', 0));
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('qtyPerUnitOfMeasure', ReadText(ResponseJson, 'parameter'), 'parameter');
        ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(ItemUnitOfMeasure);
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_QtyAsText_ReturnsInvalidParameterFormat()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] qtyPerUnitOfMeasure sent as text answers InvalidParameterFormat.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'UOMBOX');
        RequestJson.Add('qtyPerUnitOfMeasure', '6');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send qtyPerUnitOfMeasure as a JSON number.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_NegativeWeight_ReturnsInvalidParameter()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A negative weight answers InvalidParameter.
        ItemNo := CreateItem();
        EnsureUnit('UOMBOX');
        RequestJson := CreateRequest(ItemNo, 'UOMBOX', 6);
        RequestJson.Add('weight', -1);
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('weight', ReadText(ResponseJson, 'parameter'), 'parameter');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An unknown key answers UnknownParameter with a nextStep.
        RequestJson := CreateRequest('X', 'UOMBOX', 6);
        RequestJson.Add('color', 'blue');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Get_MissingItemNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Get without itemNo answers MissingParameter with a nextStep.
        ResponseJson := CallGet(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send the number of the item whose units of measure you want to read.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Get_UnknownUnit_ReturnsRecordNotFound()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A unit the item does not have answers RecordNotFound with a nextStep.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'NONE');
        ResponseJson := CallGet(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Omit code to list the units of the item, or create the unit with Inventory.ItemUnitOfMeasure.Create.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_Help_IsIcelandicAt1039()
    var
        Contract: Interface "Msg Contract ori";
        OriginalLanguage: Integer;
        Errors: JsonArray;
        Entry: JsonToken;
        Token: JsonToken;
        Overview: Text;
        Found: Boolean;
    begin
        // [SCENARIO AC04] The help of the existing-unit refusal and the overview are Icelandic at LCID 1039.
        Contract := "Message Type ori"::"Inventory.ItemUnitOfMeasure.Create";
        OriginalLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Contract.GetErrors(Errors);
        Contract.GetOverview(Overview);
        GlobalLanguage(OriginalLanguage);
        foreach Entry in Errors do
            if Entry.AsObject().Get('code', Token) then
                if Token.AsValue().AsText() = 'PreconditionFailed' then begin
                    Found := true;
                    Entry.AsObject().Get('fix', Token);
                    Assert.AreEqual('Veldu annan mælieiningarkóða, eða lestu eininguna sem er til með Inventory.ItemUnitOfMeasure.Get.', Token.AsValue().AsText(), 'Icelandic fix');
                end;
        Assert.IsTrue(Found, 'PreconditionFailed is declared');
        Assert.IsTrue(Overview.StartsWith('Stofnar nýja mælieiningu'), Overview);
    end;

    [Test]
    procedure TypeNames_HaveThreeParts()
    var
        TypeName: Text;
    begin
        // [SCENARIO AC05] Both message type names have exactly three dot-separated parts.
        foreach TypeName in Enum::"Message Type ori".Names() do
            if TypeName.StartsWith('Inventory.ItemUnitOfMeasure.') then
                Assert.AreEqual(3, TypeName.Split('.').Count(), TypeName);
        Assert.IsTrue(Enum::"Message Type ori".Names().Contains('Inventory.ItemUnitOfMeasure.Create'), 'Create is registered');
        Assert.IsTrue(Enum::"Message Type ori".Names().Contains('Inventory.ItemUnitOfMeasure.Get'), 'Get is registered');
    end;

    local procedure CallCreate(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemUnitOfMeasure.Create", '', RequestJson, true);
    end;

    local procedure CallGet(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemUnitOfMeasure.Get", '', RequestJson, false);
    end;

    local procedure CreateRequest(ItemNo: Text; UnitCode: Text; Qty: Decimal) RequestJson: JsonObject
    begin
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', UnitCode);
        RequestJson.Add('qtyPerUnitOfMeasure', Qty);
    end;

    local procedure EnsureUnit(UnitCode: Code[10])
    var
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if UnitOfMeasure.Get(UnitCode) then
            exit;
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := UnitCode;
        UnitOfMeasure.Insert();
    end;

    local procedure CreateItem() ItemNo: Code[20]
    var
        Item: Record Item;
    begin
        ItemNo := CopyStr('UM' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(ItemNo));
        Item.Init();
        Item.Validate("No.", ItemNo);
        Item.Validate(Description, 'Bifrost unit of measure test item');
        Item.Insert(true);
    end;

    local procedure AddBaseUnit(ItemNo: Code[20]; UnitCode: Code[10])
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure.Validate("Item No.", ItemNo);
        ItemUnitOfMeasure.Validate(Code, UnitCode);
        ItemUnitOfMeasure.Validate("Qty. per Unit of Measure", 1);
        ItemUnitOfMeasure.Insert(true);
        Item.Get(ItemNo);
        Item.Validate("Base Unit of Measure", UnitCode);
        Item.Modify(true);
    end;

    local procedure InsertLedgerEntry(ItemNo: Code[20]; UnitCode: Code[10])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        NextEntryNo: Integer;
    begin
        if ItemLedgerEntry.FindLast() then
            NextEntryNo := ItemLedgerEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ItemLedgerEntry.Init();
        ItemLedgerEntry."Entry No." := NextEntryNo;
        ItemLedgerEntry."Item No." := ItemNo;
        ItemLedgerEntry."Unit of Measure Code" := UnitCode;
        ItemLedgerEntry.Quantity := 1;
        ItemLedgerEntry."Posting Date" := WorkDate();
        ItemLedgerEntry.Insert();
    end;

    local procedure DeleteItem(ItemNo: Code[20])
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.DeleteAll();
        if Item.Get(ItemNo) then begin
            Item."Base Unit of Measure" := '';
            Item.Modify();
        end;
        ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
        ItemUnitOfMeasure.DeleteAll();
        if Item.Get(ItemNo) then
            Item.Delete(true);
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    begin
        Assert.AreEqual(Expected, ReadText(ResponseJson, 'status'), 'status');
    end;

    local procedure ReadObject(ResponseJson: JsonObject; KeyName: Text): JsonObject
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName);
        exit(Token.AsObject());
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadDecimal(ResponseJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsDecimal());
        exit(0);
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
