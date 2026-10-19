namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.AvailabilityByPeriod.Get.
/// </summary>
codeunit 96952 "Avail. By Period Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";

    [Test]
    procedure PostedItem_ReturnsPeriodRows()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PeriodsToken: JsonToken;
        PeriodToken: JsonToken;
        MessageType: Enum "Message Type ori";
        FromText: Text;
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(Item, Item.Type::Inventory);
        PostPositiveAdjustment(Item."No.", 7);
        FromText := Format(WorkDate(), 0, 9);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', FromText);
        RequestJson.Add('periods', 2);

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", Item."No.", RequestJson, false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'itemNo', Item."No.");
        AssertText(ResponseJson, 'periodType', 'month');
        Assert.IsTrue(ResponseJson.Get('periods', PeriodsToken), 'periods missing');
        Assert.AreEqual(2, PeriodsToken.AsArray().Count(), 'two periods');
        PeriodsToken.AsArray().Get(0, PeriodToken);
        AssertPeriodContains(PeriodToken.AsObject(), WorkDate());
        AssertDecimal(PeriodToken.AsObject(), 'inventory', 7);
        AssertDecimal(PeriodToken.AsObject(), 'grossRequirement', 0);
        AssertText(PeriodToken.AsObject(), 'amountType', 'netChange');
    end;

    [Test]
    procedure TwoItems_ReturnOneResultEach()
    var
        FirstItem: Record Item;
        SecondItem: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Items: JsonArray;
        ItemsToken: JsonToken;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(FirstItem, FirstItem.Type::Inventory);
        CreateItem(SecondItem, SecondItem.Type::Inventory);
        Items.Add(FirstItem."No.");
        Items.Add(SecondItem."No.");
        RequestJson.Add('items', Items);
        RequestJson.Add('periodType', 'day');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", 'BATCH', RequestJson, false);

        Library.AssertStatus(ResponseJson, 'Success');
        Assert.IsTrue(ResponseJson.Get('items', ItemsToken), 'items missing');
        Assert.AreEqual(2, ItemsToken.AsArray().Count(), 'two items');
    end;

    [Test]
    procedure MissingItemNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", '', RequestJson, false);
        AssertResponseError(ResponseJson, 'MissingParameter', 'Send itemNo, or send items');
    end;

    [Test]
    procedure UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('warehouse', 'BLUE');
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", 'ANY', RequestJson, false);
        AssertResponseError(ResponseJson, 'UnknownParameter', 'Remove the unknown key.');
    end;

    [Test]
    procedure NumberItemNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        RequestJson.Add('itemNo', 123);
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", '123', RequestJson, false);
        AssertResponseError(ResponseJson, 'InvalidParameterFormat', 'Send itemNo as text');
    end;

    [Test]
    procedure BothForms_ReturnConflictingIdentifiers()
    var
        RequestJson: JsonObject;
        Items: JsonArray;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        Items.Add('ONE');
        RequestJson.Add('itemNo', 'ONE');
        RequestJson.Add('items', Items);
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", 'ONE', RequestJson, false);
        AssertResponseError(ResponseJson, 'ConflictingIdentifiers', 'Send either itemNo or items, not both.');
    end;

    [Test]
    procedure UnknownPeriodType_ReturnsInvalidParameter()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(Item, Item.Type::Inventory);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('periodType', 'decade');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", Item."No.", RequestJson, false);
        AssertResponseError(ResponseJson, 'InvalidParameter', 'Use day, week, month, quarter or year.');
    end;

    [Test]
    procedure MissingItem_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        RequestJson.Add('itemNo', 'NO-SUCH-ITEM-ZZZ');
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", 'NO-SUCH-ITEM-ZZZ', RequestJson, false);
        AssertResponseError(ResponseJson, 'RecordNotFound', 'Check the item no.');
    end;

    [Test]
    procedure TooManyPeriods_ReturnsLimitExceeded()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(Item, Item.Type::Inventory);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('periodType', 'day');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 54);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", Item."No.", RequestJson, false);
        AssertResponseError(ResponseJson, 'LimitExceeded', 'Split the call.');
    end;

    [Test]
    procedure TooManyItems_ReturnsLimitExceeded()
    var
        RequestJson: JsonObject;
        Items: JsonArray;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
        Index: Integer;
    begin
        Library.Initialize();
        EnableAvailability();
        for Index := 1 to 21 do
            Items.Add('ITEM-' + Format(Index));
        RequestJson.Add('items', Items);
        RequestJson.Add('periodType', 'day');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", 'MANY', RequestJson, false);
        AssertResponseError(ResponseJson, 'LimitExceeded', 'Split the call.');
    end;

    [Test]
    procedure ServiceAndNonInventory_ReturnPreconditionFailed()
    var
        ServiceItem: Record Item;
        NonInventoryItem: Record Item;
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(ServiceItem, ServiceItem.Type::Service);
        CreateItem(NonInventoryItem, NonInventoryItem.Type::"Non-Inventory");
        AssertResponseError(CallItem("Message Type ori"::"Inventory.AvailabilityByPeriod.Get", ServiceItem."No."), 'PreconditionFailed', 'Use an inventory item.');
        AssertResponseError(CallItem("Message Type ori"::"Inventory.AvailabilityByPeriod.Get", NonInventoryItem."No."), 'PreconditionFailed', 'Use an inventory item.');
    end;

    [Test]
    procedure BalanceAtDate_ReturnsCumulativeBalance()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PeriodsToken: JsonToken;
        PeriodToken: JsonToken;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(Item, Item.Type::Inventory);
        PostPositiveAdjustment(Item."No.", 5);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('periodType', 'week');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        RequestJson.Add('amountType', 'balanceAtDate');

        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", Item."No.", RequestJson, false);

        Library.AssertStatus(ResponseJson, 'Success');
        AssertText(ResponseJson, 'amountType', 'balanceAtDate');
        Assert.IsTrue(ResponseJson.Get('periods', PeriodsToken), 'periods missing');
        PeriodsToken.AsArray().Get(0, PeriodToken);
        AssertText(PeriodToken.AsObject(), 'amountType', 'balanceAtDate');
        AssertDecimal(PeriodToken.AsObject(), 'projectedAvailableBalance', 5);
    end;

    [Test]
    procedure UnknownAmountType_ReturnsInvalidParameter()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        MessageType: Enum "Message Type ori";
    begin
        Library.Initialize();
        EnableAvailability();
        CreateItem(Item, Item.Type::Inventory);
        RequestJson.Add('itemNo', Item."No.");
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        RequestJson.Add('amountType', 'average');
        ResponseJson := Library.ExecuteType(MessageType::"Inventory.AvailabilityByPeriod.Get", Item."No.", RequestJson, false);
        AssertResponseError(ResponseJson, 'InvalidParameter', 'Use netChange or balanceAtDate for amountType.');
    end;

    local procedure CallItem(MessageType: Enum "Message Type ori"; ItemNo: Code[20]) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('itemNo', ItemNo);
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', Format(WorkDate(), 0, 9));
        RequestJson.Add('periods', 1);
        ResponseJson := Library.ExecuteType(MessageType, ItemNo, RequestJson, false);
    end;

    local procedure EnableAvailability()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        // New domains are opt-in for companies that already have a setup row.
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Availability then
            exit;
        InventorySetup.Validate(Availability, true);
        InventorySetup.Modify(true);
    end;

    local procedure CreateItem(var Item: Record Item; ItemType: Enum "Item Type")
    begin
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
    begin
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual(ExpectedCode, CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), ExpectedNextStepPart), NextStepToken.AsValue().AsText());
    end;

    local procedure AssertText(ResponseJson: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing');
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName);
    end;

    local procedure AssertDecimal(ResponseJson: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(KeyName, Token), KeyName + ' missing');
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), KeyName);
    end;

    local procedure AssertPeriodContains(PeriodJson: JsonObject; Day: Date)
    var
        StartToken: JsonToken;
        EndToken: JsonToken;
        PeriodStart: Date;
        PeriodEnd: Date;
    begin
        Assert.IsTrue(PeriodJson.Get('periodStart', StartToken), 'periodStart missing');
        Assert.IsTrue(PeriodJson.Get('periodEnd', EndToken), 'periodEnd missing');
        Evaluate(PeriodStart, StartToken.AsValue().AsText(), 9);
        Evaluate(PeriodEnd, EndToken.AsValue().AsText(), 9);
        Assert.IsTrue(Day >= PeriodStart, 'from date is before the period');
        Assert.IsTrue(Day <= PeriodEnd, 'from date is after the period');
    end;
}
