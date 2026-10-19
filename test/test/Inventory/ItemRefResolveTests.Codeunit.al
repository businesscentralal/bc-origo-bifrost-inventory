namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.ItemReference.Resolve.
/// </summary>
codeunit 96950 "Item Ref. Resolve Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Barcode_ReturnsItemVariantAndUnit()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(Item, false);
        CreateReference(Item, "Item Reference Type"::"Bar Code", '', 'REF-BAR-1', 0D);

        RequestJson.Add('referenceNo', 'REF-BAR-1');
        RequestJson.Add('referenceType', 'barCode');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'REF-BAR-1', RequestJson, false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'source', 'reference');
        AssertText(ResponseJson, 'itemNo', Item."No.");
        AssertText(ResponseJson, 'referenceType', 'barCode');
        AssertText(ResponseJson, 'referenceNo', 'REF-BAR-1');
        AssertBoolean(ResponseJson, 'blocked', false);
    end;

    [Test]
    procedure CustomerReference_UsesTypeNo()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(Item, false);
        CreateReference(Item, "Item Reference Type"::Customer, 'C-100', 'CUST-ITEM', 0D);

        RequestJson.Add('referenceNo', 'CUST-ITEM');
        RequestJson.Add('referenceType', 'customer');
        RequestJson.Add('referenceTypeNo', 'C-100');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'CUST-ITEM', RequestJson, false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'itemNo', Item."No.");
        AssertText(ResponseJson, 'referenceType', 'customer');
        AssertText(ResponseJson, 'referenceTypeNo', 'C-100');
    end;

    [Test]
    procedure ItemNo_IsUsedWhenNoReferenceExists()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(Item, false);
        RequestJson.Add('referenceNo', Item."No.");
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", Item."No.", RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'source', 'itemNo');
        AssertText(ResponseJson, 'itemNo', Item."No.");
    end;

    [Test]
    procedure Gtin_IsUsedWhenNoReferenceExists()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
        Gtin: Code[14];
    begin
        Library.Initialize();
        CreateItem(Item, false);
        Gtin := '5901234123457';
        Item.Validate(GTIN, Gtin);
        Item.Modify(true);
        RequestJson.Add('referenceNo', Gtin);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", Gtin, RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'source', 'gtin');
        AssertText(ResponseJson, 'itemNo', Item."No.");
    end;

    [Test]
    procedure ReferencesArray_ReturnsOneResultEach()
    var
        FirstItem: Record Item;
        SecondItem: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        References: JsonArray;
        First: JsonObject;
        Second: JsonObject;
        ResultsToken: JsonToken;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(FirstItem, false);
        CreateItem(SecondItem, false);
        CreateReference(FirstItem, "Item Reference Type"::"Bar Code", '', 'BATCH-1', 0D);
        CreateReference(SecondItem, "Item Reference Type"::"Bar Code", '', 'BATCH-2', 0D);
        First.Add('referenceNo', 'BATCH-1');
        First.Add('referenceType', 'barCode');
        Second.Add('referenceNo', 'BATCH-2');
        Second.Add('referenceType', 'barCode');
        References.Add(First);
        References.Add(Second);
        RequestJson.Add('references', References);

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'BATCH', RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('results', ResultsToken), 'results missing');
        Assert.AreEqual(2, ResultsToken.AsArray().Count(), 'two results');
    end;

    [Test]
    procedure MissingReferenceNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", '', RequestJson, false);
        AssertResolveError(ResponseJson, 'MissingParameter', 'Send referenceNo, or send references with a referenceNo on each entry.');
    end;

    [Test]
    procedure UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        RequestJson.Add('referenceNo', 'ANY');
        RequestJson.Add('warehouse', 'BLUE');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'ANY', RequestJson, false);
        AssertResolveError(ResponseJson, 'UnknownParameter', 'Remove the unknown key.');
    end;

    [Test]
    procedure NumberReferenceNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        RequestJson.Add('referenceNo', 123);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", '123', RequestJson, false);
        AssertResolveError(ResponseJson, 'InvalidParameterFormat', 'Send referenceNo as text');
    end;

    [Test]
    procedure BothForms_ReturnConflictingIdentifiers()
    var
        RequestJson: JsonObject;
        References: JsonArray;
        Entry: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        Entry.Add('referenceNo', 'ONE');
        References.Add(Entry);
        RequestJson.Add('referenceNo', 'ONE');
        RequestJson.Add('references', References);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'ONE', RequestJson, false);
        AssertResolveError(ResponseJson, 'ConflictingIdentifiers', 'Send either referenceNo or references, not both.');
    end;

    [Test]
    procedure UnknownType_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        RequestJson.Add('referenceNo', 'ANY');
        RequestJson.Add('referenceType', 'warehouse');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'ANY', RequestJson, false);
        AssertResolveError(ResponseJson, 'InvalidParameter', 'Use barCode, customer, vendor, or leave referenceType empty.');
    end;

    [Test]
    procedure NothingMatches_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        RequestJson.Add('referenceNo', 'NO-SUCH-REF-ZZZ');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'NO-SUCH-REF-ZZZ', RequestJson, false);
        AssertResolveError(ResponseJson, 'RecordNotFound', 'Check the barcode, or add the reference in BC (Item References).');
    end;

    [Test]
    procedure TwoItems_ReturnAmbiguousRecord()
    var
        FirstItem: Record Item;
        SecondItem: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(FirstItem, false);
        CreateItem(SecondItem, false);
        CreateReference(FirstItem, "Item Reference Type"::"Bar Code", '', 'SAME-BAR', 0D);
        CreateReference(SecondItem, "Item Reference Type"::"Bar Code", '', 'SAME-BAR', 0D);
        RequestJson.Add('referenceNo', 'SAME-BAR');
        RequestJson.Add('referenceType', 'barCode');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'SAME-BAR', RequestJson, false);
        AssertResolveError(ResponseJson, 'AmbiguousRecord', 'Pass referenceType and referenceTypeNo to narrow it.');
    end;

    [Test]
    procedure BarcodeWithTypeNo_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        RequestJson.Add('referenceNo', 'BAR');
        RequestJson.Add('referenceType', 'barCode');
        RequestJson.Add('referenceTypeNo', 'C-100');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'BAR', RequestJson, false);
        AssertResolveError(ResponseJson, 'InvalidParameter', 'Leave referenceTypeNo empty for barcodes.');
    end;

    [Test]
    procedure EndedReference_IsIgnored()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(Item, false);
        CreateReference(Item, "Item Reference Type"::"Bar Code", '', 'ENDED-REF', CalcDate('<-2D>', WorkDate()));
        RequestJson.Add('referenceNo', 'ENDED-REF');
        RequestJson.Add('referenceType', 'barCode');
        RequestJson.Add('date', Format(WorkDate(), 0, 9));
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'ENDED-REF', RequestJson, false);
        AssertResolveError(ResponseJson, 'RecordNotFound', 'Check the barcode, or add the reference in BC (Item References).');
    end;

    [Test]
    procedure BlockedItem_ReturnsBlockedTrue()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        CreateItem(Item, true);
        CreateReference(Item, "Item Reference Type"::"Bar Code", '', 'BLOCKED-REF', 0D);
        RequestJson.Add('referenceNo', 'BLOCKED-REF');
        RequestJson.Add('referenceType', 'barCode');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.ItemReference.Resolve", 'BLOCKED-REF', RequestJson, false);
        Library.AssertStatus(ResponseJson, 'Success');
        AssertBoolean(ResponseJson, 'blocked', true);
        AssertText(ResponseJson, 'itemNo', Item."No.");
    end;

    local procedure CreateItem(var Item: Record Item; Blocked: Boolean)
    begin
        Item.Init();
        Item.Validate("No.", CopyStr('IR' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(Item."No.")));
        Item.Validate(Description, Item."No.");
        Item.Insert(true);
        if not Blocked then
            exit;
        Item.Validate(Blocked, true);
        Item.Modify(true);
    end;

    local procedure CreateReference(Item: Record Item; ReferenceType: Enum "Item Reference Type"; TypeNo: Code[20]; ReferenceNo: Code[50]; EndingDate: Date)
    var
        ItemReference: Record "Item Reference";
    begin
        ItemReference.Init();
        ItemReference.Validate("Item No.", Item."No.");
        ItemReference.Validate("Reference Type", ReferenceType);
        if TypeNo <> '' then
            ItemReference."Reference Type No." := TypeNo;
        ItemReference.Validate("Reference No.", ReferenceNo);
        if EndingDate <> 0D then
            ItemReference.Validate("Ending Date", EndingDate);
        ItemReference.Insert(true);
    end;

    local procedure AssertText(ResponseJson: JsonObject; Name: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(Name, Token), Name + ' missing');
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Name);
    end;

    local procedure AssertBoolean(ResponseJson: JsonObject; Name: Text; Expected: Boolean)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(Name, Token), Name + ' missing');
        Assert.AreEqual(Expected, Token.AsValue().AsBoolean(), Name);
    end;

    local procedure AssertResolveError(ResponseJson: JsonObject; Code: Text; NextStepPart: Text)
    var
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Library.AssertStatus(ResponseJson, 'Error');
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual(Code, CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), NextStepPart), NextStepToken.AsValue().AsText());
    end;
}
