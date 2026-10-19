namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.OrderTracking.Get: the tracking chain of sales, purchase, transfer and assembly lines and of an
/// item ledger entry, read-only behaviour, refusals and help.
/// </summary>
codeunit 96962 "Order Tracking Get Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryPurchase: Codeunit "Library - Purchase";

    [Test]
    procedure OrderTracking_ReservedSalesLine_ReturnsChainAndWritesNothing()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entry: JsonObject;
        EntriesBefore: Integer;
    begin
        // [GIVEN] A sales order line for 2, reserved from inventory.
        EnableReservations();
        CreateStockedItem(Item, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        ReserveSalesLine(SalesLine);
        EntriesBefore := ReservationEntry.Count();
        // [WHEN] Its order tracking is read.
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        // [THEN] The chain links the sales line to the item ledger entry, with quantity and date.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Sales', ReadText(ResponseJson, 'sourceKind'), 'sourceKind');
        Assert.IsTrue(FindEntry(ResponseJson, Database::"Sales Line", SalesLine."Document No.", SalesLine."Line No.", Database::"Item Ledger Entry", Entry), 'sales line tracked against inventory');
        Assert.AreEqual(2, ReadDecimal(Entry, 'quantity'), 'quantity');
        Assert.AreEqual('Item Ledger Entry', ReadText(Entry, 'fromTypeName'), 'fromTypeName');
        Assert.AreEqual('Sales Line', ReadText(Entry, 'forTypeName'), 'forTypeName');
        Assert.AreEqual(Format(SalesLine."Shipment Date", 0, 9), ReadText(Entry, 'shipmentDate'), 'shipmentDate');
        Assert.AreEqual(Item."No.", ReadText(Entry, 'itemNo'), 'itemNo');
        // [THEN] Nothing was written.
        Assert.AreEqual(EntriesBefore, ReservationEntry.Count(), 'read only');
        CleanupSales(SalesHeader, Item."No.");
    end;

    [Test]
    procedure OrderTracking_PurchaseLineSupplyingSalesLine_ReturnsChain()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entry: JsonObject;
    begin
        // [GIVEN] An item without stock, a purchase order line for 5 and a sales order line for 2 reserved against it.
        EnableReservations();
        CreateStockedItem(Item, 0);
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 5);
        PurchaseLine.Validate("Expected Receipt Date", WorkDate());
        PurchaseLine.Modify(true);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        SalesLine.Validate("Shipment Date", WorkDate() + 7);
        SalesLine.Modify(true);
        ReserveSalesLine(SalesLine);
        // [WHEN] The order tracking of the purchase line is read, by SystemId.
        RequestJson.Add('sourceKind', 'Purchase');
        RequestJson.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        ResponseJson := CallTrack(RequestJson);
        // [THEN] The chain links the purchase line to the sales line.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.IsTrue(FindEntry(ResponseJson, Database::"Purchase Line", PurchaseLine."Document No.", PurchaseLine."Line No.", Database::"Sales Line", Entry), 'purchase line supplies the sales line');
        Assert.AreEqual(SalesLine."Document No.", ReadText(Entry, 'fromNo'), 'fromNo');
        Assert.AreEqual(SalesLine."Line No.", ReadDecimal(Entry, 'fromLineNo'), 'fromLineNo');
        CleanupSales(SalesHeader, Item."No.");
        PurchaseHeader.Find();
        PurchaseHeader.Delete(true);
    end;

    [Test]
    procedure OrderTracking_ItemLedgerEntry_ReturnsChain()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entry: JsonObject;
    begin
        // [GIVEN] A sales order line reserved from an item ledger entry.
        EnableReservations();
        CreateStockedItem(Item, 5);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 2);
        ReserveSalesLine(SalesLine);
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.FindFirst();
        // [WHEN] The order tracking of the item ledger entry is read.
        RequestJson.Add('sourceKind', 'ItemLedgerEntry');
        RequestJson.Add('entryNo', ItemLedgerEntry."Entry No.");
        ResponseJson := CallTrack(RequestJson);
        // [THEN] The chain links the entry to the sales line.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.IsTrue(FindEntry(ResponseJson, Database::"Item Ledger Entry", '', ItemLedgerEntry."Entry No.", Database::"Sales Line", Entry), 'entry supplies the sales line');
        Assert.AreEqual(SalesLine."Document No.", ReadText(Entry, 'fromNo'), 'fromNo');
        CleanupSales(SalesHeader, Item."No.");
    end;

    [Test]
    procedure OrderTracking_ReservedTransferLine_ReturnsOutboundChain()
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ReservationManagement: Codeunit "Reservation Management";
        Helper: Codeunit "Transfer Order Test Helper";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entry: JsonObject;
        FullAutoReservation: Boolean;
    begin
        // [GIVEN] A transfer line for 2 whose shipment side is reserved from stock at the from-location.
        EnableReservations();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 5);
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 2);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        ReservationManagement.SetReservSource(TransferLine, "Transfer Direction"::Outbound);
        ReservationManagement.AutoReserve(FullAutoReservation, '', TransferLine."Shipment Date", TransferLine."Outstanding Quantity", TransferLine."Outstanding Qty. (Base)");
        Assert.IsTrue(FullAutoReservation, 'transfer line reserved');
        // [WHEN] Its order tracking is read.
        RequestJson.Add('sourceKind', 'Transfer');
        RequestJson.Add('documentNo', TransferLine."Document No.");
        RequestJson.Add('lineNo', TransferLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        // [THEN] The chain links the shipment side of the transfer line to the item ledger entry.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.IsTrue(FindEntry(ResponseJson, Database::"Transfer Line", TransferLine."Document No.", TransferLine."Line No.", Database::"Item Ledger Entry", Entry), 'transfer line tracked against inventory');
        Assert.AreEqual(2, ReadDecimal(Entry, 'quantity'), 'quantity');
    end;

    [Test]
    procedure OrderTracking_ReservedAssemblyLine_ReturnsChain()
    var
        ParentItem: Record Item;
        ComponentItem: Record Item;
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        ReservationManagement: Codeunit "Reservation Management";
        Helper: Codeunit "Assembly Order Test Helper";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entry: JsonObject;
        FullAutoReservation: Boolean;
    begin
        // [GIVEN] An assembly order whose component line is reserved from stock.
        EnableReservations();
        Helper.CreateAssemblyItemWithBOM(ParentItem, ComponentItem);
        ComponentItem.Validate(Reserve, ComponentItem.Reserve::Optional);
        ComponentItem.Modify(true);
        Helper.CreatePositiveAdjustment(ComponentItem."No.", 5);
        Helper.CreateAssemblyOrder(AssemblyHeader, ParentItem."No.", 2);
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        AssemblyLine.FindFirst();
        ReservationManagement.SetReservSource(AssemblyLine);
        ReservationManagement.AutoReserve(FullAutoReservation, '', AssemblyLine."Due Date", AssemblyLine."Remaining Quantity", AssemblyLine."Remaining Quantity (Base)");
        Assert.IsTrue(FullAutoReservation, 'assembly line reserved');
        // [WHEN] Its order tracking is read.
        RequestJson.Add('sourceKind', 'Assembly');
        RequestJson.Add('documentNo', AssemblyLine."Document No.");
        RequestJson.Add('lineNo', AssemblyLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        // [THEN] The chain links the component line to the item ledger entry.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.IsTrue(FindEntry(ResponseJson, Database::"Assembly Line", AssemblyLine."Document No.", AssemblyLine."Line No.", Database::"Item Ledger Entry", Entry), 'assembly line tracked against inventory');
    end;

    [Test]
    procedure OrderTracking_UnreservedLine_ReturnsEmptyChain()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        // [GIVEN] A sales order line with nothing reserved or tracked.
        EnableReservations();
        CreateStockedItem(Item, 2);
        CreateSalesLine(SalesHeader, SalesLine, Item."No.", 1);
        // [WHEN] Its order tracking is read; documentType defaults to Order.
        RequestJson.Add('sourceKind', 'sales');
        RequestJson.Add('documentNo', SalesLine."Document No.");
        RequestJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson := CallTrack(RequestJson);
        // [THEN] Success with an empty chain.
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual(0, ReadArray(ResponseJson, 'entries').Count(), 'empty chain');
        CleanupSales(SalesHeader, Item."No.");
    end;

    [Test]
    procedure OrderTracking_MissingLine_ReturnsRecordNotFound()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Purchase');
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('RecordNotFound', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Check the document and line no.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OrderTracking_MissingSourceKind_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('sourceKind', ReadText(ResponseJson, 'parameter'), 'parameter');
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OrderTracking_MissingLineNo_ReturnsMissingParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Transfer');
        RequestJson.Add('documentNo', 'MISSING112');
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('MissingParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('lineNo', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure OrderTracking_UnsupportedSourceKind_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Service');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('sourceKind', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure OrderTracking_EntryNoForSales_ReturnsInvalidParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('entryNo', 1);
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('InvalidParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('entryNo', ReadText(ResponseJson, 'parameter'), 'parameter');
    end;

    [Test]
    procedure OrderTracking_BadEntryNo_ReturnsInvalidParameterFormat()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'ItemLedgerEntry');
        RequestJson.Add('entryNo', 'first');
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('InvalidParameterFormat', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreEqual('Send entryNo as an integer.', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OrderTracking_SystemIdAndDocument_ReturnsConflictingIdentifiers()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('systemId', Format(CreateGuid(), 0, 4));
        RequestJson.Add('documentNo', 'MISSING112');
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('ConflictingIdentifiers', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OrderTracking_UnknownKey_ReturnsUnknownParameter()
    var
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        EnableReservations();
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('documentNo', 'MISSING112');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('itemNo', 'X');
        ResponseJson := CallTrack(RequestJson);
        Assert.AreEqual('UnknownParameter', ReadText(ResponseJson, 'code'), ReadText(ResponseJson, 'error'));
        Assert.AreNotEqual('', ReadText(ResponseJson, 'nextStep'), 'nextStep');
    end;

    [Test]
    procedure OrderTracking_Help_CoversRefusalsInBothLanguages()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TrackImpl: Codeunit "Order Tracking Get Impl ori";
        Contract: JsonObject;
        ContractText: Text;
        EnglishNotes: Text;
        IcelandicNotes: Text;
        PreviousLanguage: Integer;
    begin
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.OrderTracking.Get", Contract), 'contract');
        Contract.WriteTo(ContractText);
        Assert.IsTrue(ContractText.Contains('RecordNotFound'), 'RecordNotFound');
        Assert.IsTrue(ContractText.Contains('MissingParameter'), 'MissingParameter');
        Assert.IsTrue(ContractText.Contains('ConflictingIdentifiers'), 'ConflictingIdentifiers');
        Assert.IsTrue(ContractText.Contains('PermissionDenied'), 'PermissionDenied');
        Assert.IsTrue(Contract.Contains('examples'), 'examples');
        Assert.IsFalse(ContractText.Contains('Order Tracking Management'), 'no codeunit names');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.IsTrue(TrackImpl.GetNotes(EnglishNotes), 'English notes');
        GlobalLanguage(1039);
        Assert.IsTrue(TrackImpl.GetNotes(IcelandicNotes), 'Icelandic notes');
        GlobalLanguage(PreviousLanguage);
        Assert.AreNotEqual(EnglishNotes, IcelandicNotes, 'notes follow LCID 1039');
    end;

    local procedure FindEntry(ResponseJson: JsonObject; ForType: Integer; ForNo: Code[20]; ForLineNo: Integer; FromType: Integer; var Found: JsonObject): Boolean
    var
        EntryToken: JsonToken;
        Entry: JsonObject;
    begin
        foreach EntryToken in ReadArray(ResponseJson, 'entries') do begin
            Entry := EntryToken.AsObject();
            if (ReadDecimal(Entry, 'forType') = ForType) and (ReadText(Entry, 'forNo') = ForNo) and (ReadDecimal(Entry, 'forLineNo') = ForLineNo) and (ReadDecimal(Entry, 'fromType') = FromType) then begin
                Found := Entry;
                exit(true);
            end;
        end;
        exit(false);
    end;

    local procedure EnableReservations()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.Get() then
            InventorySetup.InsertIfNotExists();
        if InventorySetup.Reservations then
            exit;
        InventorySetup.Validate(Reservations, true);
        InventorySetup.Modify(true);
    end;

    local procedure CreateStockedItem(var Item: Record Item; Qty: Decimal)
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItem(Item);
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        if Qty <= 0 then
            exit;
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

    local procedure ReserveSalesLine(var SalesLine: Record "Sales Line")
    var
        Library: Codeunit "Inventory Test Library ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.Reservation.AutoReserve", '', RequestJson, false);
        Assert.AreEqual('Success', ReadText(ResponseJson, 'status'), 'AutoReserve: ' + ReadText(ResponseJson, 'error'));
        Assert.IsTrue(ReadBoolean(ResponseJson, 'fullyReserved'), 'sales line fully reserved');
        SalesLine.Find();
    end;

    local procedure CallTrack(RequestJson: JsonObject) ResponseJson: JsonObject
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        ResponseJson := Library.ExecuteType("Message Type ori"::"Inventory.OrderTracking.Get", '', RequestJson, false);
    end;

    local procedure CleanupSales(var SalesHeader: Record "Sales Header"; ItemNo: Code[20])
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.DeleteAll(true);
        if SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.") then
            SalesHeader.Delete(true);
    end;

    local procedure ReadText(Json: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Json.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDecimal(Json: JsonObject; KeyName: Text): Decimal
    var
        Result: Decimal;
    begin
        if Evaluate(Result, ReadText(Json, KeyName), 9) then
            exit(Result);
        exit(0);
    end;

    local procedure ReadBoolean(Json: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Json.Get(KeyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadArray(Json: JsonObject; KeyName: Text): JsonArray
    var
        Token: JsonToken;
        Empty: JsonArray;
    begin
        if not Json.Get(KeyName, Token) then
            exit(Empty);
        if not Token.IsArray() then
            exit(Empty);
        exit(Token.AsArray());
    end;
}
