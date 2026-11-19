namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Requisition;
using Microsoft.Purchases.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AvailableToPromise.Get (#105).
/// </summary>
codeunit 96926 "Avail. To Promise Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryPlanning: Codeunit "Library - Planning";

    [Test]
    procedure OnHand_CanPromiseOnRequestedDate()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        // [SCENARIO AC01] Stock on hand covers the quantity, so it can be promised on the requested date.
        Initialize();
        CreateItem(Item, Item.Type::Inventory);
        PostPositiveAdjustment(Item."No.", 7);

        ResponseJson := Call(Item."No.", 5, WorkDate(), false);

        Library.AssertStatus(ResponseJson, 'Success');
        Library.AssertResponseContract(MessageType::"Inventory.AvailableToPromise.Get", ResponseJson);
        AssertText(ResponseJson, 'itemNo', Item."No.");
        AssertText(ResponseJson, 'requestedDate', Format(WorkDate(), 0, 9));
        AssertDecimal(ResponseJson, 'availableOnRequestedDate', 7);
        AssertBoolean(ResponseJson, 'canPromiseOnRequestedDate', true);
        AssertText(ResponseJson, 'earliestDate', Format(WorkDate(), 0, 9));
        AssertText(ResponseJson, 'basis', 'availableToPromise');
        // [SCENARIO AC02] Capable to promise is off when it is not sent.
        AssertBoolean(ResponseJson, 'capableToPromise', false);
        AssertText(ResponseJson, 'capableToPromiseDate', '');
    end;

    [Test]
    procedure FutureReceipt_EarliestDateIsReceiptDate()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseJson: JsonObject;
        ReceiptDate: Date;
    begin
        // [SCENARIO AC01] Two on hand and five more on a purchase order: ten can be promised from the receipt date.
        Initialize();
        CreateItem(Item, Item.Type::Inventory);
        PostPositiveAdjustment(Item."No.", 2);
        ReceiptDate := CalcDate('<+10D>', WorkDate());
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 8);
        PurchaseLine.Validate("Expected Receipt Date", ReceiptDate);
        PurchaseLine.Modify(true);

        ResponseJson := Call(Item."No.", 10, WorkDate(), false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertDecimal(ResponseJson, 'availableOnRequestedDate', 2);
        AssertBoolean(ResponseJson, 'canPromiseOnRequestedDate', false);
        AssertText(ResponseJson, 'earliestDate', Format(ReceiptDate, 0, 9));
        AssertText(ResponseJson, 'availableToPromiseDate', Format(ReceiptDate, 0, 9));
    end;

    /// <summary>
    /// A receipt before the request promises the requested date.
    /// </summary>
    [Test]
    procedure Scenario_AC01_EarlierReceipt_PromisesRequestedDate()
    begin
        // Story #105, AC01 | Time: receipt WorkDate + 10D, request + 20D | Risk: None
        Initialize();
        AssertReceiptPromisesRequestedDate(CalcDate('<+10D>', WorkDate()), CalcDate('<+20D>', WorkDate()), false);
    end;

    /// <summary>
    /// A receipt on the requested date remains promiseable that day.
    /// </summary>
    [Test]
    procedure Scenario_AC01_ReceiptOnRequestedDate_PromisesRequestedDate()
    begin
        // Story #105, AC01 | Time: receipt and request WorkDate + 10D | Risk: None
        Initialize();
        AssertReceiptPromisesRequestedDate(CalcDate('<+10D>', WorkDate()), CalcDate('<+10D>', WorkDate()), false);
    end;

    /// <summary>
    /// Enabling CTP preserves the requested-date lower bound for an earlier ATP receipt.
    /// </summary>
    [Test]
    procedure Scenario_AC02_EarlierReceiptWithCapable_PromisesRequestedDate()
    begin
        // Story #105, AC01/AC02 | Time: receipt WorkDate + 10D, request + 20D | Risk: None
        Initialize();
        EnsureOrderPromisingSetup();
        AssertReceiptPromisesRequestedDate(CalcDate('<+10D>', WorkDate()), CalcDate('<+20D>', WorkDate()), true);
    end;

    local procedure AssertReceiptPromisesRequestedDate(ReceiptDate: Date; RequestedDate: Date; UseCapable: Boolean)
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO] A receipt on or before the request covers the promised quantity.
        // [GIVEN] No stock on hand and an open purchase receipt of ten.
        CreateItem(Item, Item.Type::Inventory);
        Item.Rename(CopyStr('X' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Item."No.")));
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        PurchaseLine.Validate("Expected Receipt Date", ReceiptDate);
        PurchaseLine.Modify(true);

        // [WHEN] The message asks for five on or after that receipt.
        ResponseJson := Call(Item."No.", 5, RequestedDate, UseCapable);

        // [THEN] Both ATP dates respect the request lower bound, including when CTP also runs.
        Library.AssertStatus(ResponseJson, 'Success');
        AssertDecimal(ResponseJson, 'availableOnRequestedDate', 10);
        AssertBoolean(ResponseJson, 'canPromiseOnRequestedDate', true);
        AssertText(ResponseJson, 'earliestDate', Format(RequestedDate, 0, 9));
        AssertText(ResponseJson, 'availableToPromiseDate', Format(RequestedDate, 0, 9));
        AssertText(ResponseJson, 'basis', 'availableToPromise');
        AssertBoolean(ResponseJson, 'capableToPromise', UseCapable);
    end;

    [Test]
    procedure NoSupply_EarliestDateIsEmpty()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC01 edge] Nothing on hand and nothing coming: no date can be promised.
        Initialize();
        CreateItem(Item, Item.Type::Inventory);

        ResponseJson := Call(Item."No.", 3, WorkDate(), false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertDecimal(ResponseJson, 'availableOnRequestedDate', 0);
        AssertBoolean(ResponseJson, 'canPromiseOnRequestedDate', false);
        AssertText(ResponseJson, 'earliestDate', '');
        AssertText(ResponseJson, 'basis', '');
    end;

    [Test]
    procedure CapableToPromise_KeepsNoLines()
    var
        Item: Record Item;
        RequisitionLine: Record "Requisition Line";
        OrderPromisingLine: Record "Order Promising Line";
        ResponseJson: JsonObject;
        RequisitionCount: Integer;
        PromisingCount: Integer;
    begin
        // [SCENARIO AC02, AC03] Capable to promise runs when asked, and no requisition or order promising lines are kept.
        Initialize();
        EnsureOrderPromisingSetup();
        CreateItem(Item, Item.Type::Inventory);
        RequisitionCount := RequisitionLine.Count();
        PromisingCount := OrderPromisingLine.Count();

        ResponseJson := Call(Item."No.", 4, WorkDate(), true);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertBoolean(ResponseJson, 'capableToPromise', true);
        Assert.AreEqual(RequisitionCount, RequisitionLine.Count(), 'No requisition line is kept.');
        Assert.AreEqual(PromisingCount, OrderPromisingLine.Count(), 'No order promising line is kept.');
    end;

    [Test]
    procedure CapableToPromise_WithoutSetup_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        OrderPromisingSetup: Record "Order Promising Setup";
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] Capable to promise without an order promising worksheet is refused with a nextStep.
        Initialize();
        if not OrderPromisingSetup.Get() then
            OrderPromisingSetup.Insert();
        OrderPromisingSetup."Order Promising Worksheet" := '';
        OrderPromisingSetup.Modify();
        CreateItem(Item, Item.Type::Inventory);

        ResponseJson := Call(Item."No.", 1, WorkDate(), true);

        AssertResponseError(ResponseJson, 'PreconditionFailed', 'Order Promising Setup page');
    end;

    [Test]
    procedure ZeroQuantity_ReturnsInvalidParameter()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A quantity of 0 is refused.
        Initialize();
        CreateItem(Item, Item.Type::Inventory);
        ResponseJson := Call(Item."No.", 0, WorkDate(), false);
        AssertResponseError(ResponseJson, 'InvalidParameter', 'Send a quantity above 0');
        AssertText(ResponseJson, 'parameter', 'quantity');
    end;

    [Test]
    procedure TextQuantity_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] quantity sent as text is refused.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', '5');
        RequestJson.Add('requestedDate', Format(WorkDate(), 0, 9));
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'quantity as a number');
    end;

    [Test]
    procedure BadDate_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] requestedDate that is not a date is refused.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 5);
        RequestJson.Add('requestedDate', 'next week');
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'requestedDate as YYYY-MM-DD');
    end;

    [Test]
    procedure MissingRequestedDate_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] requestedDate is required.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 5);
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'MissingParameter', 'Send itemNo, quantity and requestedDate.');
        AssertText(ResponseJson, 'parameter', 'requestedDate');
    end;

    [Test]
    procedure TextCapable_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] capableToPromise must be a JSON boolean.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 5);
        RequestJson.Add('requestedDate', Format(WorkDate(), 0, 9));
        RequestJson.Add('capableToPromise', 'yes');
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'capableToPromise as true or false');
    end;

    [Test]
    procedure UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A key the type does not read is refused.
        Initialize();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 5);
        RequestJson.Add('requestedDate', Format(WorkDate(), 0, 9));
        RequestJson.Add('unitOfMeasure', 'PCS');
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'UnknownParameter', 'Remove the unknown key.');
    end;

    [Test]
    procedure MissingItem_ReturnsRecordNotFound()
    var
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] An item that does not exist is refused.
        Initialize();
        ResponseJson := Call('NO-SUCH-ITEM-105', 1, WorkDate(), false);
        AssertResponseError(ResponseJson, 'RecordNotFound', 'Check the item no.');
    end;

    [Test]
    procedure UnknownLocation_ReturnsRecordNotFound()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A location that does not exist is refused.
        Initialize();
        CreateItem(Item, Item.Type::Inventory);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('location', 'NOLOC105');
        RequestJson.Add('quantity', 1);
        RequestJson.Add('requestedDate', Format(WorkDate(), 0, 9));
        ResponseJson := Execute(RequestJson);
        AssertResponseError(ResponseJson, 'RecordNotFound', 'Check the location code.');
    end;

    [Test]
    procedure ServiceItem_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        ResponseJson: JsonObject;
    begin
        // [SCENARIO AC04] A service item has no availability.
        Initialize();
        CreateItem(Item, Item.Type::Service);
        ResponseJson := Call(Item."No.", 1, WorkDate(), false);
        AssertResponseError(ResponseJson, 'PreconditionFailed', 'Use an inventory item.');
    end;

    [Test]
    procedure DomainOff_OnlyHidesType()
    var
        TempArgument: Record "Message Argument ori" temporary;
        InventorySetup: Record "Inventory Setup ori";
        PromiseImpl: Codeunit "Avail. To Promise Impl ori";
        DomainCheck: Codeunit "Inv. MCP Fixture ori";
        RequestJson: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [SCENARIO Issue36 ruling 18.11.2026] Availability off only hides the type; execution is not refused for the domain, also in is-IS at 1039.
        Initialize();
        InventorySetup.Get();
        InventorySetup.Validate(Availability, false);
        InventorySetup.Modify(true);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 1);
        RequestJson.Add('requestedDate', Format(WorkDate(), 0, 9));
        TempArgument.SetRequestJson(RequestJson);
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        DomainCheck.AssertDomainOffOnlyHidesType(PromiseImpl, TempArgument);
        GlobalLanguage(PreviousLanguage);
    end;

    [Test]
    procedure Name_HasThreeParts()
    var
        MessageType: Enum "Message Type ori";
        Parts: List of [Text];
    begin
        // [SCENARIO AC05] The name has exactly three dot-separated parts.
        MessageType := MessageType::"Inventory.AvailableToPromise.Get";
        Parts := Format(MessageType).Split('.');
        Assert.AreEqual(3, Parts.Count(), 'The message type name has three parts.');
    end;

    local procedure Initialize()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Availability then
            exit;
        InventorySetup.Validate(Availability, true);
        InventorySetup.Modify(true);
    end;

    local procedure Call(ItemNo: Text; Quantity: Decimal; RequestedDate: Date; CapableToPromise: Boolean): JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('quantity', Quantity);
        RequestJson.Add('requestedDate', Format(RequestedDate, 0, 9));
        if CapableToPromise then
            RequestJson.Add('capableToPromise', true);
        exit(Execute(RequestJson));
    end;

    local procedure Execute(RequestJson: JsonObject): JsonObject
    var
        MessageType: Enum "Message Type ori";
    begin
        exit(Library.ExecuteType(MessageType::"Inventory.AvailableToPromise.Get", 'ATP', RequestJson, false));
    end;

    local procedure EnsureOrderPromisingSetup()
    var
        OrderPromisingSetup: Record "Order Promising Setup";
        RequisitionWkshName: Record "Requisition Wksh. Name";
    begin
        if not OrderPromisingSetup.Get() then
            OrderPromisingSetup.Insert();
        if (OrderPromisingSetup."Order Promising Template" <> '') and (OrderPromisingSetup."Order Promising Worksheet" <> '') then
            exit;
        LibraryPlanning.SelectRequisitionWkshName(RequisitionWkshName, "Req. Worksheet Template Type"::Planning);
        OrderPromisingSetup."Order Promising Template" := RequisitionWkshName."Worksheet Template Name";
        OrderPromisingSetup."Order Promising Worksheet" := RequisitionWkshName.Name;
        OrderPromisingSetup.Modify();
    end;

    local procedure CreateItem(var Item: Record Item; ItemType: Enum "Item Type")
    begin
        if ItemType = Item.Type::Service then begin
            Clear(Item);
            repeat
                Item."No." := CopyStr('X' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Item."No."));
            until not Item.Get(Item."No.");
            Item.Validate(Type, ItemType);
            Item.Insert(true);
            exit;
        end;
        LibraryInventory.CreateItem(Item);
        if Item.Type = ItemType then
            exit;
        Item.Validate(Type, ItemType);
        Item.Modify(true);
    end;

    local procedure PostPositiveAdjustment(ItemNo: Code[20]; Qty: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(
            ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name,
            "Item Ledger Entry Type"::"Positive Adjmt.", ItemNo, Qty);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure AssertResponseError(ResponseJson: JsonObject; ExpectedCode: Text; ExpectedNextStepPart: Text)
    var
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing: ' + ResponseText);
        Assert.AreEqual(ExpectedCode, CodeToken.AsValue().AsText(), ResponseText);
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing: ' + ResponseText);
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), ExpectedNextStepPart), NextStepToken.AsValue().AsText());
    end;

    local procedure AssertText(ResponseJson: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName + ': ' + ResponseText);
    end;

    local procedure AssertDecimal(ResponseJson: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), KeyName + ': ' + ResponseText);
    end;

    local procedure AssertBoolean(ResponseJson: JsonObject; KeyName: Text; Expected: Boolean)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        ResponseText := ResponseText.Replace('"', '''');
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing: ' + ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsBoolean(), KeyName + ': ' + ResponseText);
    end;
}
