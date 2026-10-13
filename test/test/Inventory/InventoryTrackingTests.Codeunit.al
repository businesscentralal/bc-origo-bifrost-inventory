namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Exercises native source tracking with independently created purchase lines and tracking data.</summary>
codeunit 96925 "Inventory Tracking Tests"
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
        EntryNumbers: JsonArray;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        CreatePurchaseLine(OtherLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        ReservationEntry.FindFirst();
        EntryNumbers.Add(ReservationEntry."Entry No.");
        Request.Add('source', SourceObject(OtherLine));
        Request.Add('entryNos', EntryNumbers);

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
        EntryNumbers: JsonArray;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-B', '', 3), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        ReservationEntry.SetRange("Lot No.", 'LOT-A');
        ReservationEntry.FindFirst();
        EntryNumbers.Add(ReservationEntry."Entry No.");
        Request.Add('source', SourceObject(PurchaseLine));
        Request.Add('entryNos', EntryNumbers);

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Selected lot is removed.');
        ReservationEntry.SetRange("Lot No.", 'LOT-B');
        ReservationEntry.FindFirst();
        Assert.AreEqual(3, ReservationEntry."Quantity (Base)", 'Other lot remains unchanged.');
    end;

    /// <summary>An explicit empty selection is a no-op rather than deleting every source entry.</summary>
    [Test]
    procedure EmptyDeleteSelectionPreservesTracking()
    var
        PurchaseLine: Record "Purchase Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        EntryNumbers: JsonArray;
    begin
        CreatePurchaseLine(PurchaseLine, false);
        ExecuteTracking(AssignmentRequest(PurchaseLine, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        Request.Add('source', SourceObject(PurchaseLine));
        Request.Add('entryNos', EntryNumbers);

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.AreEqual(1, ReservationEntry.Count(), 'An empty selection does not remove tracking.');
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
