namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Reservation.AutoReserve and Inventory.OrderTracking.Get.
/// </summary>
codeunit 96930 "Reserv. AutoReserve Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";

    [Test]
    procedure AutoReserve_SalesLineWithStock_ReservesAndTracks()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
    begin
        CreateStockedItem(Item, Item.Reserve::Optional, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        RequestJson := LineRequest(SalesLine);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.AreEqual(true, ReadBoolean(ResponseJson, 'fullyReserved'), 'fullyReserved');
        Assert.IsTrue(ReadDecimal(ResponseJson, 'reserved') > 0, 'reserved');
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Assert.AreEqual(2, SalesLine."Reserved Quantity", 'line reserved quantity');

        Clear(RequestJson);
        RequestJson := LineRequest(SalesLine);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'second status');
        Assert.AreEqual(0, ReadDecimal(ResponseJson, 'reserved'), 'second reserved');
        Assert.AreEqual(true, ReadBoolean(ResponseJson, 'fullyReserved'), 'second fullyReserved');

        Clear(RequestJson);
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'tracking status');
        Assert.IsTrue(ResponseJson.Get('entries', Token), 'entries');
        Entries := Token.AsArray();
        Assert.IsTrue(Entries.Count() > 0, 'tracking chain');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_ReserveNever_ReturnsPreconditionFailed()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        ResponseJson: JsonObject;
    begin
        CreateStockedItem(Item, Item.Reserve::Never, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 1);
        ResponseJson := CallAuto(LineRequest(SalesLine));
        Assert.AreEqual('PreconditionFailed', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Change the item''s Reserve setting or reserve manually.'), ReadText(ResponseJson, 'nextStep'));
        ReservationEntry.SetRange("Item No.", Item."No.");
        Assert.AreEqual(0, ReservationEntry.Count(), 'nothing written');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure AutoReserve_MissingLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Check the document and line no.'), ReadText(ResponseJson, 'nextStep'));
    end;

    [Test]
    procedure AutoReserve_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('extra', 'no');
        ResponseJson := CallAuto(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure AutoReserve_PartialSupply_RollsBack()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        ResponseJson: JsonObject;
    begin
        CreateStockedItem(Item, Item.Reserve::Optional, 1);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 5);
        ResponseJson := CallAuto(LineRequest(SalesLine));
        Assert.AreEqual('LinesSkipped', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Read Inventory.Reservation.Get for what was reserved.'), ReadText(ResponseJson, 'nextStep'));
        ReservationEntry.SetRange("Source ID", SalesHeader."No.");
        Assert.AreEqual(0, ReservationEntry.Count(), 'partial reserve was rolled back');
        Cleanup(SalesHeader, Item."No.");
    end;

    [Test]
    procedure OrderTracking_MissingLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('sourceKind', 'Purchase');
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'Check the document and line no.'), ReadText(ResponseJson, 'nextStep'));
    end;

    [Test]
    procedure OrderTracking_UnreservedLine_ReturnsEmptyChain()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
    begin
        CreateStockedItem(Item, Item.Reserve::Optional, 2);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 1);
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'status');
        Assert.IsTrue(ResponseJson.Get('entries', Token), 'entries');
        Assert.AreEqual(0, Token.AsArray().Count(), 'empty chain');
        Cleanup(SalesHeader, Item."No.");
    end;

    local procedure CreateStockedItem(var Item: Record Item; ReserveMethod: Enum "Reserve Method"; Qty: Decimal)
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate(Reserve, ReserveMethod);
        Item.Modify(true);
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type::Item, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, "Item Ledger Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure CreateSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; ItemNo: Code[20]; Qty: Decimal)
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Qty);
    end;

    local procedure LineRequest(SalesLine: Record "Sales Line") RequestJson: JsonObject
    begin
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
    end;

    local procedure CallAuto(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.Reservation.AutoReserve", '', RequestJson, false);
    end;

    local procedure CallTrack(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.OrderTracking.Get", '', RequestJson, false);
    end;

    local procedure Cleanup(var SalesHeader: Record "Sales Header"; ItemNo: Code[20])
    var
        ReservationEntry: Record "Reservation Entry";
        Item: Record Item;
    begin
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.DeleteAll(true);
        if SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.") then
            SalesHeader.Delete(true);
        if Item.Get(ItemNo) then
            Item.Delete(true);
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
        Result: Decimal;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() and Evaluate(Result, Token.AsValue().AsText()) then
            exit(Result);
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
