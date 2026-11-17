namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemVariant.Create and Inventory.ItemVariant.Get (#99): happy paths, coded refusals with a nextStep in
/// both languages, the existing-variant and empty-item edge cases and the Data.Records write restriction on Item Variant.
/// </summary>
codeunit 96988 "Item Variant Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Create_NewVariant_SavesAndAnswersVariant()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
        VariantJson: JsonObject;
    begin
        // [SCENARIO AC01] Create takes item no., code, description and blocked and answers the saved variant.
        ItemNo := CreateItem();
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'BLUE', 'Blue chair', true));
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ReadBoolean(ResponseJson, 'created'), 'created');
        Assert.AreEqual(ItemNo, ReadText(ResponseJson, 'itemNo'), 'itemNo');
        VariantJson := ReadObject(ResponseJson, 'variant');
        Assert.AreEqual('BLUE', ReadText(VariantJson, 'code'), 'code');
        Assert.AreEqual('Blue chair', ReadText(VariantJson, 'description'), 'description');
        Assert.IsTrue(ReadBoolean(VariantJson, 'blocked'), 'blocked');
        Assert.IsTrue(ItemVariant.Get(ItemNo, 'BLUE'), 'the variant is saved');
        Assert.AreEqual('Blue chair', ItemVariant.Description, 'saved description');
        Assert.IsTrue(ItemVariant.Blocked, 'saved blocked');
        Assert.AreEqual(Format(ItemVariant.SystemId, 0, 4).ToLower(), ReadText(VariantJson, 'systemId'), 'systemId');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_LowerCaseCode_IsSavedUpperCase()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01] Only itemNo and code are needed; the code is a Code field, so it is saved in upper case.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'red');
        ResponseJson := CallCreate(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual('RED', ReadText(ReadObject(ResponseJson, 'variant'), 'code'), 'code');
        Assert.IsTrue(ItemVariant.Get(ItemNo, 'RED'), 'saved');
        Assert.IsFalse(ItemVariant.Blocked, 'blocked defaults to false');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_ExistingVariant_ReturnsPreconditionFailed()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04 edge] A second Create with the same code is refused and the first variant is unchanged.
        ItemNo := CreateItem();
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'BLUE', 'First', false)), 'Success');
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'BLUE', 'Second', true));
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Choose another variant code, or read the existing variant with Inventory.ItemVariant.Get.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemVariant.Get(ItemNo, 'BLUE');
        Assert.AreEqual('First', ItemVariant.Description, 'the existing variant is unchanged');
        Assert.IsFalse(ItemVariant.Blocked, 'the existing variant stays unblocked');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_UnknownItem_ReturnsRecordNotFound()
    var
        ItemVariant: Record "Item Variant";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An item that does not exist answers RecordNotFound with a nextStep; nothing is saved.
        ResponseJson := CallCreate(CreateRequest('IV99-MISSING', 'BLUE', '', false));
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('itemNo', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Check the item number. The item must exist before a variant can be created on it.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemVariant.SetRange("Item No.", 'IV99-MISSING');
        Assert.RecordIsEmpty(ItemVariant);
    end;

    [Test]
    procedure Create_MissingCode_ReturnsMissingParameter()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A missing code answers MissingParameter with a nextStep; nothing is saved.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send the code of the new variant, at most 10 characters.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemVariant.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(ItemVariant);
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_CodeTooLong_ReturnsInvalidParameter()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A code longer than 10 characters answers InvalidParameter; nothing is saved.
        ItemNo := CreateItem();
        ResponseJson := CallCreate(CreateRequest(ItemNo, 'ELEVENCHARS', '', false));
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send code with at most 10 characters.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemVariant.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(ItemVariant);
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_BlockedAsText_ReturnsInvalidParameterFormat()
    var
        ItemVariant: Record "Item Variant";
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] blocked sent as text answers InvalidParameterFormat; nothing is saved.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'BLUE');
        RequestJson.Add('blocked', 'yes');
        ResponseJson := CallCreate(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send blocked as true or false.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        ItemVariant.SetRange("Item No.", ItemNo);
        Assert.RecordIsEmpty(ItemVariant);
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Create_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An unknown key answers UnknownParameter with a nextStep.
        RequestJson.Add('itemNo', 'X');
        RequestJson.Add('code', 'BLUE');
        RequestJson.Add('color', 'blue');
        ResponseJson := CallCreate(RequestJson);
        // Foundation's strict parameter check answers first for an Inbound type, with its own nextStep.
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
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
        // [SCENARIO AC04] The help of the existing-variant refusal and the overview are Icelandic at LCID 1039.
        Contract := "Message Type ori"::"Inventory.ItemVariant.Create";
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
                    Assert.AreEqual('Veldu annan afbrigðiskóða, eða lestu afbrigðið sem er til með Inventory.ItemVariant.Get.', Token.AsValue().AsText(), 'Icelandic fix');
                end;
        Assert.IsTrue(Found, 'PreconditionFailed is declared');
        Assert.IsTrue(Overview.StartsWith('Stofnar nýtt afbrigði'), Overview);
    end;

    [Test]
    procedure Get_Item_AnswersEveryVariantInCodeOrder()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Variants: JsonArray;
        Token: JsonToken;
    begin
        // [SCENARIO AC02] Get answers every variant of the item.
        ItemNo := CreateItem();
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'RED', 'Red', false)), 'Success');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'BLUE', 'Blue', true)), 'Success');
        RequestJson.Add('itemNo', ItemNo);
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.AreEqual(ItemNo, ReadText(ResponseJson, 'itemNo'), 'itemNo');
        Assert.IsTrue(ResponseJson.Get('variants', Token), 'variants');
        Variants := Token.AsArray();
        Assert.AreEqual(2, Variants.Count(), 'two variants');
        Variants.Get(0, Token);
        Assert.AreEqual('BLUE', ReadText(Token.AsObject(), 'code'), 'first in code order');
        Assert.IsTrue(ReadBoolean(Token.AsObject(), 'blocked'), 'blue is blocked');
        Variants.Get(1, Token);
        Assert.AreEqual('RED', ReadText(Token.AsObject(), 'code'), 'second in code order');
        Assert.AreEqual('Red', ReadText(Token.AsObject(), 'description'), 'red description');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_ItemAndCode_AnswersOneVariant()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO AC02] code narrows the answer to one variant.
        ItemNo := CreateItem();
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'RED', 'Red', false)), 'Success');
        AssertStatus(CallCreate(CreateRequest(ItemNo, 'BLUE', 'Blue', false)), 'Success');
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'red');
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('variants', Token), 'variants');
        Assert.AreEqual(1, Token.AsArray().Count(), 'one variant');
        Token.AsArray().Get(0, Token);
        Assert.AreEqual('RED', ReadText(Token.AsObject(), 'code'), 'code');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_ItemWithoutVariants_AnswersEmptyArray()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO AC02 edge] An item without variants answers Success with an empty array, not an error.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        ResponseJson := CallGet(RequestJson);
        AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('variants', Token), 'variants');
        Assert.AreEqual(0, Token.AsArray().Count(), 'no variants');
        DeleteItem(ItemNo);
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
        Assert.AreEqual('itemNo', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Send the number of the item whose variants you want to read.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure Get_UnknownVariant_ReturnsRecordNotFound()
    var
        ItemNo: Code[20];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A variant code the item does not have answers RecordNotFound with a nextStep.
        ItemNo := CreateItem();
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', 'NONE');
        ResponseJson := CallGet(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('code', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreEqual('Omit code to list the variants of the item, or create the variant with Inventory.ItemVariant.Create.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
        DeleteItem(ItemNo);
    end;

    [Test]
    procedure Get_ItemNoAsNumber_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] itemNo sent as a JSON number answers InvalidParameterFormat.
        RequestJson.Add('itemNo', 1000);
        ResponseJson := CallGet(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreEqual('Send itemNo as text.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure DataRecords_WriteRestricted_ItemVariant()
    var
        TempArgument: Record "Message Argument ori" temporary;
        ErrorText: Text;
    begin
        // [SCENARIO AC03] Data.Records.Set is refused on table 5401 and names the dedicated types; reads stay allowed.
        TempArgument.Init();
        TempArgument.Insert(true);
        Assert.IsTrue(TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Variant", false), '5401 write restricted');
        Assert.IsFalse(TempArgument.IsTableReadRestrictedForDataRecords(Database::"Item Variant"), '5401 reads stay allowed');
        Assert.AreEqual('Inventory.ItemVariant.Get / Inventory.ItemVariant.Create', TempArgument.GetDedicatedMessageTypeHintForWrite(Database::"Item Variant"), '5401 hint');
        ErrorText := TempArgument.GetRestrictedTableErrorText(Database::"Item Variant", 'Blocked.', true);
        Assert.AreNotEqual(0, StrPos(ErrorText, 'Inventory.ItemVariant.Create'), ErrorText);
    end;

    [Test]
    procedure TypeNames_HaveThreeParts()
    var
        TypeName: Text;
    begin
        // [SCENARIO AC05] Both message type names have exactly three dot-separated parts.
        foreach TypeName in Enum::"Message Type ori".Names() do
            if TypeName.StartsWith('Inventory.ItemVariant.') then
                Assert.AreEqual(3, TypeName.Split('.').Count(), TypeName);
        Assert.IsTrue(Enum::"Message Type ori".Names().Contains('Inventory.ItemVariant.Create'), 'Create is registered');
        Assert.IsTrue(Enum::"Message Type ori".Names().Contains('Inventory.ItemVariant.Get'), 'Get is registered');
    end;

    local procedure CallCreate(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemVariant.Create", '', RequestJson, true);
    end;

    local procedure CallGet(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.ItemVariant.Get", '', RequestJson, false);
    end;

    local procedure CreateRequest(ItemNo: Text; VariantCode: Text; Description: Text; Blocked: Boolean) RequestJson: JsonObject
    begin
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('code', VariantCode);
        if Description <> '' then
            RequestJson.Add('description', Description);
        RequestJson.Add('blocked', Blocked);
    end;

    local procedure CreateItem() ItemNo: Code[20]
    var
        Item: Record Item;
    begin
        ItemNo := CopyStr('IV' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(ItemNo));
        Item.Init();
        Item.Validate("No.", ItemNo);
        Item.Validate(Description, 'Bifrost variant test item');
        Item.Insert(true);
    end;

    local procedure DeleteItem(ItemNo: Code[20])
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
    begin
        ItemVariant.SetRange("Item No.", ItemNo);
        ItemVariant.DeleteAll(true);
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

    local procedure ReadBoolean(ResponseJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
