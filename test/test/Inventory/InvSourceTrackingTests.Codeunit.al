namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Exercises native source tracking with independently created purchase lines and tracking data.</summary>
codeunit 96974 "Inv. Source Tracking Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";

    /// <summary>Assignment belongs to the source line and never inserts a persistent tracking specification.</summary>
    [Test]
    procedure AssignLotUsesSourceReservationAndNoPersistentSpecification()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        Request: JsonObject;
        Response: JsonObject;
        CountBefore: Integer;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        CountBefore := TrackingSpecification.Count();
        Request := AssignmentRequest(PurchaseLine, 'LOT-A', '', 2);

        ExecuteTracking(Request, false, Response);

        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.AreEqual(1, ReservationEntry.Count(), 'One source-bound tracking entry.');
        ReservationEntry.FindFirst();
        Assert.AreEqual('LOT-A', ReservationEntry."Lot No.", 'Assigned lot.');
        Assert.AreEqual(2, ReservationEntry."Quantity (Base)", 'Assigned purchase quantity.');
        Assert.AreEqual(CountBefore, TrackingSpecification.Count(), 'No direct persistent tracking specification insert.');
    end;

    /// <summary>Serial quantity validation refuses multiple units before native writes.</summary>
    [Test]
    procedure SerialQuantityTwoIsRefusedWithoutWrites()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, true);

        ExecuteTracking(AssignmentRequest(PurchaseLine, '', 'SERIAL-A', 2), false, Response);

        AssertStatus(Response, 'Error');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Invalid serial quantity creates no tracking.');
    end;

    /// <summary>A later invalid row prevents assignment of earlier valid rows.</summary>
    [Test]
    procedure InvalidSecondEntryLeavesSourceUnchanged()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
        Entry: JsonObject;
        Token: JsonToken;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        Request := AssignmentRequest(PurchaseLine, 'LOT-A', '', 1);
        Request.Get('entries', Token);
        Entries := Token.AsArray();
        Entry.Add('serialNo', 'SERIAL-B');
        Entry.Add('quantity', 2);
        Entries.Add(Entry);
        Request.Replace('entries', Entries);

        ExecuteTracking(Request, false, Response);

        AssertStatus(Response, 'Error');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Validation is complete before the first assignment.');
    end;

    /// <summary>An entry belonging to another line cannot be removed.</summary>
    [Test]
    procedure DeleteRejectsEntryFromDifferentSource()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        CreatePurchaseLine(OtherLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        ReservationEntry.FindFirst();
        Request.Add('source', SourceObject(OtherLine));
        Request.Add('entryNo', ReservationEntry."Entry No.");

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Error');
        Assert.AreEqual(1, ReservationEntry.Count(), 'Foreign source entry must remain.');
    end;

    /// <summary>Deleting one entry preserves tracking belonging to a different lot on the same line.</summary>
    [Test]
    procedure DeleteSelectedEntryPreservesOtherTracking()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-B', '', 3), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        ReservationEntry.SetRange("Lot No.", 'LOT-A');
        ReservationEntry.FindFirst();
        Request.Add('source', SourceObject(PurchaseLine));
        Request.Add('entryNo', ReservationEntry."Entry No.");

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Selected lot is removed.');
        ReservationEntry.SetRange("Lot No.", 'LOT-B');
        ReservationEntry.FindFirst();
        Assert.AreEqual(3, ReservationEntry."Quantity (Base)", 'Other lot remains unchanged.');
    end;

    /// <summary>A missing entryNo is refused rather than deleting every source entry.</summary>
    [Test]
    procedure EmptyDeleteSelectionPreservesTracking()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        Request.Add('source', SourceObject(PurchaseLine));
        

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Error');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.AreEqual(1, ReservationEntry.Count(), 'An empty selection does not remove tracking.');
    end;

    /// <summary>Sales tracking uses a self-posted lot and deletes only pending demand tracking.</summary>
    [Test]
    procedure SalesTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        LibrarySales: Codeunit "Library - Sales";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 10);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(Line, Header, Line.Type::Item, PurchaseLine."No.", 10);

        AssertTrackingRoundTrip(GenericSource('SalesLine', Line.SystemId), Database::"Sales Line", Line."Document No.", Line."Line No.", false);
    end;

    /// <summary>Transfer tracking uses real locations and self-posted stock through the native transfer run mode.</summary>
    [Test]
    procedure TransferTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        FromLocation: Record Location;
        ToLocation: Record Location;
        TransitLocation: Record Location;
        Header: Record "Transfer Header";
        Line: Record "Transfer Line";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Source: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        LibraryWarehouse.CreateTransferLocations(FromLocation, ToLocation, TransitLocation);
        PurchaseLine.Validate("Location Code", FromLocation.Code);
        PurchaseLine.Modify(true);
        PostTrackedReceipt(PurchaseLine, 10);
        LibraryInventory.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
        LibraryInventory.CreateTransferLine(Header, Line, PurchaseLine."No.", 10);
        Source := GenericSource('TransferLine', Line.SystemId);
        Source.Add('transferDirection', 'Outbound');

        AssertTrackingRoundTrip(Source, Database::"Transfer Line", Line."Document No.", Line."Line No.", false);
    end;

    /// <summary>Removing unposted purchase tracking after a partial receipt cannot undo the posted lot quantity.</summary>
    [Test]
    procedure PartialReceiptDeletePreservesPostedLedger()
    var
        PurchaseLine: Record "Purchase Line";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 4);
        Request.Add('source', SourceObject(PurchaseLine));
        Ledger.SetRange("Item No.", PurchaseLine."No.");
        Ledger.SetRange("Lot No.", 'ROUND-LOT');
        Ledger.CalcSums(Quantity);
        Assert.AreEqual(4, Ledger.Quantity, 'Fixture really posted a partial receipt.');
        FilterSourceEntries(PurchaseLine, Entry);
        Entry.CalcSums("Quantity (Base)");
        Assert.AreEqual(6, Entry."Quantity (Base)", 'Six tracked units remain pending.');

        Entry.FindFirst();
        Request.Add('entryNo', Entry."Entry No.");
        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Only pending purchase tracking was removed.');
        Ledger.CalcSums(Quantity);
        Assert.AreEqual(4, Ledger.Quantity, 'Deleting pending tracking cannot change posted inventory.');
    end;

    /// <summary>The supported single-entry API round-trips lot and serial source tracking in both runtime languages.</summary>
    [Test]
    procedure BilingualLotAndSerialRoundTrip()
    var
        SavedLanguage: Integer;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        AssertPublicRoundTrip(false);
        AssertPublicRoundTrip(true);
        GlobalLanguage(1039);
        AssertPublicRoundTrip(false);
        AssertPublicRoundTrip(true);
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertPublicRoundTrip(Serial: Boolean)
    var
        Line: Record "Purchase Line";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Request: JsonObject;
        Response: JsonObject;
        ReadRequest: JsonObject;
        DeleteRequest: JsonObject;
        Token: JsonToken;
        Rows: JsonArray;
        Row: JsonObject;
        EntryNo: Integer;
    begin
        CreatePurchaseLine(Line, Serial);
        Request.Add('source', SourceObject(Line));
        Request.Add('itemNo', Line."No.");
        Request.Add('quantity', 1);
        if Serial then
            Request.Add('serialNo', 'SERIAL-ROUND')
        else begin
            Request.Add('lotNo', 'LOT-ROUND');
            Request.Add('packageNo', 'PACKAGE-ROUND');
        end;
        ExecuteTracking(Request, false, Response);
        AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.Get('entryNo', Token), 'Single-entry compatibility response includes the native reservation entry.');
        EntryNo := Token.AsValue().AsInteger();
        Assert.IsTrue(EntryNo > 0, 'Native entry allocation never returns zero.');
        ReadRequest.Add('source', SourceObject(Line));
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(ReadRequest);
        TrackingRead.ReadTracking(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('trackingLines', Token);
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'Exactly the assigned tracking entry is visible.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Row.Get('entryNo', Token);
        Assert.AreEqual(EntryNo, Token.AsValue().AsInteger(), 'Readback identifies the created native entry.');
        DeleteRequest.Add('source', SourceObject(Line));
        DeleteRequest.Add('entryNo', EntryNo);
        ExecuteTracking(DeleteRequest, true, Response);
        AssertStatus(Response, 'Success');
        TempArgument.SetRequestJson(ReadRequest);
        TrackingRead.ReadTracking(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'Deleted pending tracking is absent.');
    end;

    /// <summary>The optional old item key cannot redirect tracking away from the explicitly selected line.</summary>
    [Test]
    procedure ItemMismatchDoesNotWrite()
    var
        Line: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePurchaseLine(Line, false);
        Request := AssignmentRequest(Line, 'MISMATCH', '', 1);
        Request.Add('itemNo', 'OTHER-ITEM');
        ExecuteTracking(Request, false, Response);
        AssertStatus(Response, 'Error');
        FilterSourceEntries(Line, Entry);
        Assert.IsTrue(Entry.IsEmpty(), 'Mismatch refused before native tracking.');
    end;

    /// <summary>An unavailable receipt undo never appears as enabled, even when the caller can post.</summary>
    [Test]
    procedure ReceiptUndoRemainsDisabledCompatibilityIdentifier()
    var
        ReceiptUndo: Codeunit "Transf Undo Rcpt Impl ori";
        Contract: JsonObject;
    begin
        Assert.IsFalse(ReceiptUndo.IsEnabled(), 'The unavailable receipt undo is excluded from the active roster.');
        Assert.IsTrue(ReceiptUndo.GetEffect(Contract), 'Released interface remains available for compatibility.');
    end;

    local procedure PostTrackedReceipt(var PurchaseLine: Record "Purchase Line"; ReceiveQuantity: Decimal)
    var
        Header: Record "Purchase Header";
        Response: JsonObject;
    begin
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'ROUND-LOT', '', 10), false, Response);
        AssertStatus(Response, 'Success');
        PurchaseLine.Validate("Qty. to Receive", ReceiveQuantity);
        PurchaseLine.Modify(true);
        Header.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(Header, true, false);
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
    end;

    local procedure GenericSource(TypeName: Text; SystemId: Guid) Source: JsonObject
    begin
        Source.Add('type', TypeName);
        Source.Add('systemId', Format(SystemId, 0, 4));
    end;

    local procedure AssertTrackingRoundTrip(Source: JsonObject; SourceTable: Integer; SourceId: Code[20]; RefNo: Integer; Positive: Boolean)
    var
        Entry: Record "Reservation Entry";
        Specification: Record "Tracking Specification";
        Request: JsonObject;
        DeleteRequest: JsonObject;
        Tracking: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        BeforeSpecifications: Integer;
    begin
        BeforeSpecifications := Specification.Count();
        Request.Add('source', Source);
        Tracking.Add('lotNo', 'ROUND-LOT');
        Tracking.Add('quantity', 2);
        Entries.Add(Tracking);
        Request.Add('entries', Entries);
        ExecuteTracking(Request, false, Response);
        AssertStatus(Response, 'Success');
        Entry.SetRange("Source Type", SourceTable);
        Entry.SetRange("Source ID", SourceId);
        Entry.SetRange("Source Ref. No.", RefNo);
        Entry.SetRange(Positive, Positive);
        Entry.SetRange("Lot No.", 'ROUND-LOT');
        Assert.AreEqual(1, Entry.Count(), 'One selected native source tracking row.');
        Entry.FindFirst();
        Assert.AreEqual(2, Abs(Entry."Quantity (Base)"), 'Tracking has the requested base quantity.');
        Assert.AreEqual(BeforeSpecifications, Specification.Count(), 'Assignment did not create persistent tracking specification rows.');
        DeleteRequest.Add('source', Source);
        DeleteRequest.Add('entryNo', Entry."Entry No.");

        ExecuteTracking(DeleteRequest, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Pending tracking was removed on the selected source.');
    end;

    local procedure CreatePurchaseLine(var PurchaseLine: Record "Purchase Line"; SerialTracking: Boolean)
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        PurchaseHeader: Record "Purchase Header";
    begin
        LibraryInventory.CreateItemTrackingCode(ItemTrackingCode);
        ItemTrackingCode."SN Specific Tracking" := SerialTracking;
        ItemTrackingCode."Lot Specific Tracking" := not SerialTracking;
        ItemTrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
        Item.Modify(true);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
    end;

    local procedure SourceObject(PurchaseLine: Record "Purchase Line") Source: JsonObject
    begin
        Source.Add('type', 'PurchaseLine');
        Source.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
    end;

    local procedure AssignmentRequest(PurchaseLine: Record "Purchase Line"; LotNo: Text; SerialNo: Text; Quantity: Decimal) Request: JsonObject
    var
        Entry: JsonObject;
        Entries: JsonArray;
    begin
        Request.Add('source', SourceObject(PurchaseLine));
        Entry.Add('lotNo', LotNo);
        Entry.Add('serialNo', SerialNo);
        Entry.Add('quantity', Quantity);
        Entries.Add(Entry);
        Request.Add('entries', Entries);
    end;

    local procedure ExecuteTracking(Request: JsonObject; DeleteMode: Boolean; var Response: JsonObject)
    var
        TempArgument: Record "Message Argument ori" temporary;
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        if DeleteMode then
            TrackingWrite.SetDeleteMode();
        TrackingWrite.Run(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure FilterSourceEntries(PurchaseLine: Record "Purchase Line"; var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry.Reset();
        ReservationEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservationEntry.SetRange("Source Subtype", PurchaseLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", PurchaseLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", PurchaseLine."Line No.");
    end;

    local procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Token: JsonToken;
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        Assert.IsTrue(Response.Get('status', Token), ResponseText);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), ResponseText);
    end;
}
