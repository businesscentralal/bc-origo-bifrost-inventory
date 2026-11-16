namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
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

    /// <summary>Omitting entry numbers removes all unposted tracking belonging to the selected source.</summary>
    [Test]
    procedure Scenario_AC03_OmittedEntryNumbersRemovesSourceTracking()
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

        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Omitting entry numbers removes the selected source tracking.');
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
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
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
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        TrackingRead.ReadTracking(TempArgument);
        AssertStatus(TempArgument.GetResponseJson(), 'Success');
        DeleteRequest.Add('source', Source);
        DeleteRequest.Add('entryNo', Entry."Entry No.");

        ExecuteTracking(DeleteRequest, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Pending tracking was removed on the selected source.');
    end;

    /// <summary>Native output tracking on an assembly header keeps the complete source pointer.</summary>
    [Test]
    procedure Scenario_AC01_AssemblyOutputTrackingRoundTrips()
    var
        PurchaseLine: Record "Purchase Line";
        Header: Record "Assembly Header";
        LibraryAssembly: Codeunit "Library - Assembly";
    begin
        // Story #37, AC01 | Time: WorkDate for native source date | Risk: None
        // [GIVEN] An independently created tracked item and assembly order.
        CreatePurchaseLine(PurchaseLine, false);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), PurchaseLine."No.", '', 10, '');
        // [WHEN] Tracking is assigned and removed through the native adapters.
        // [THEN] Only tracking for this assembly source changes.
        AssertTrackingRoundTrip(GenericSource('AssemblyHeader', Header.SystemId), Database::"Assembly Header", Header."No.", 0, true);
    end;

    /// <summary>Assembly consumption tracking uses its component line rather than the output header.</summary>
    [Test]
    procedure Scenario_AC01_AssemblyComponentTrackingRoundTrips()
    var
        PurchaseLine: Record "Purchase Line";
        ParentItem: Record Item;
        Header: Record "Assembly Header";
        Line: Record "Assembly Line";
        LibraryAssembly: Codeunit "Library - Assembly";
    begin
        // Story #37, AC01 | Time: WorkDate for native source date | Risk: None
        // [GIVEN] Self-posted lot stock and a separate assembly component source.
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 10);
        LibraryInventory.CreateItem(ParentItem);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), ParentItem."No.", '', 10, '');
        LibraryAssembly.CreateAssemblyLine(Header, Line, Line.Type::Item, PurchaseLine."No.", PurchaseLine."Unit of Measure Code", 10, 1, '');
        // [WHEN] Component tracking is assigned and removed.
        // [THEN] Only the selected native component source changes.
        AssertTrackingRoundTrip(GenericSource('AssemblyLine', Line.SystemId), Database::"Assembly Line", Header."No.", Line."Line No.", false);
    end;

    /// <summary>Native item journal tracking preserves template, batch and line identity.</summary>
    [Test]
    procedure Scenario_AC01_ItemJournalTrackingRoundTrips()
    var
        PurchaseLine: Record "Purchase Line";
        ItemJournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        // Story #37, AC01 | Time: WorkDate for native journal date | Risk: None
        // [GIVEN] A self-created positive adjustment journal and tracked item.
        CreatePurchaseLine(PurchaseLine, false);
        LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, Line."Entry Type"::"Positive Adjmt.", PurchaseLine."No.", 10);
        // [WHEN] Tracking is assigned and removed through the native adapters.
        // [THEN] The selected journal source alone is affected.
        AssertTrackingRoundTrip(GenericSource('ItemJournalLine', Line.SystemId), Database::"Item Journal Line", ItemJournalTemplate.Name, Line."Line No.", true);
    end;

    /// <summary>A bulk selection validates every source entry before any removal.</summary>
    [Test]
    procedure Scenario_AC03_ForeignSecondEntryLeavesBothSourcesUnchanged()
    var
        Line: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        EntryNumbers: JsonArray;
    begin
        // Story #37, AC03 | Time: WorkDate through fixture | Risk: None
        // [GIVEN] Tracking on two independent source lines.
        CreatePurchaseLine(Line, false);
        CreatePurchaseLine(OtherLine, false);
        ExecuteTracking(AssignmentRequest(Line, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(Line, Entry);
        Entry.FindFirst();
        EntryNumbers.Add(Entry."Entry No.");
        ExecuteTracking(AssignmentRequest(OtherLine, 'LOT-B', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(OtherLine, Entry);
        Entry.FindFirst();
        EntryNumbers.Add(Entry."Entry No.");
        Request.Add('source', SourceObject(Line));
        Request.Add('entryNos', EntryNumbers);
        // [WHEN] The second entry belongs to another source.
        ExecuteTracking(Request, true, Response);
        // [THEN] The whole request fails before removal.
        AssertStatus(Response, 'Error');
        Assert.AreEqual(1, Entry.Count(), 'Foreign tracking remains.');
        FilterSourceEntries(Line, Entry);
        Assert.AreEqual(1, Entry.Count(), 'Earlier valid selection remains.');
    end;

    /// <summary>A duplicate entry selection is removed once and an empty explicit array is refused.</summary>
    [Test]
    procedure Scenario_AC03_DuplicateSelectionCountsOnce()
    var
        Line: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        EntryNumbers: JsonArray;
        Token: JsonToken;
    begin
        // Story #37, AC03 | Time: WorkDate through fixture | Risk: None
        // [GIVEN] One tracked source and an explicitly empty selection.
        CreatePurchaseLine(Line, false);
        ExecuteTracking(AssignmentRequest(Line, 'LOT-A', '', 2), false, Response);
        AssertStatus(Response, 'Success');
        Request.Add('source', SourceObject(Line));
        Request.Add('entryNos', EntryNumbers);
        // [WHEN] An empty explicit array is sent.
        ExecuteTracking(Request, true, Response);
        // [THEN] It is refused and tracking remains.
        AssertStatus(Response, 'Error');
        FilterSourceEntries(Line, Entry);
        Entry.FindFirst();
        EntryNumbers.Add(Entry."Entry No.");
        EntryNumbers.Add(Entry."Entry No.");
        Request.Replace('entryNos', EntryNumbers);
        ExecuteTracking(Request, true, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entriesDeleted', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Duplicates count once.');
        Assert.IsTrue(Entry.IsEmpty(), 'Selected tracking removed.');
    end;

    /// <summary>A fractional number cannot round to an existing entry and remove it.</summary>
    [Test]
    procedure Scenario_AC03_FractionalEntryNumber_PreservesTracking()
    var
        Line: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNumbers: JsonArray;
        FractionalEntryNo: Decimal;
    begin
        // Story #37, AC03 | Time: no date dependency | Risk: independently created purchase source only.
        // [GIVEN] An existing source entry that an integer conversion could round to.
        CreatePurchaseLine(Line, false);
        ExecuteTracking(AssignmentRequest(Line, 'LOT-FRACTION', '', 1), false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(Line, Entry);
        Entry.FindFirst();
        FractionalEntryNo := Entry."Entry No." + 0.1;
        EntryNumbers.Add(FractionalEntryNo);
        Request.Add('source', SourceObject(Line));
        Request.Add('entryNos', EntryNumbers);

        // [WHEN] The API helper validates the selected entries before deleting any tracking.
        ExecuteTracking(Request, true, Response);

        // [THEN] The fractional selection is refused rather than rounded to the owned entry.
        AssertStatus(Response, 'Error');
        Response.Get('code', Token);
        Assert.AreEqual('InvalidParameterFormat', Token.AsValue().AsText(), 'Entry numbers must be positive whole numbers.');
        Assert.AreEqual(1, Entry.Count(), 'Fractional input must preserve the existing tracking row.');
    end;

    /// <summary>Disabled tracking writes return the corrected setup precondition in English.</summary>
    [Test]
    procedure Scenario_AC01_DisabledTracking_In1033()
    begin
        // Story #37, AC01 | Time: no date dependency | Risk: own test-company setup only.
        AssertDisabledTracking(1033);
    end;

    /// <summary>Disabled tracking writes return the corrected setup precondition in Icelandic.</summary>
    [Test]
    procedure Scenario_AC01_DisabledTracking_In1039()
    begin
        // Story #37, AC01 | Time: no date dependency | Risk: own test-company setup only.
        AssertDisabledTracking(1039);
    end;

    local procedure AssertDisabledTracking(LanguageId: Integer)
    var
        Setup: Record "Inventory Setup ori";
        ReservationEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        AssignImpl: Codeunit "Tracking Assign Impl ori";
        DeleteImpl: Codeunit "Tracking Delete Impl ori";
        PreviousLanguage: Integer;
        ReservationCount: Integer;
        SpecificationCount: Integer;
    begin
        // [GIVEN] The company switch is off, independently of source permissions and request validity.
        Setup.InsertIfNotExists();
        Setup."Item Tracking" := false;
        Setup.Modify();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        ReservationCount := ReservationEntry.Count();
        SpecificationCount := TrackingSpecification.Count();
        Assert.IsFalse(AssignImpl.IsEnabled(), 'Assignment discovery must honor the company switch.');
        Assert.IsFalse(DeleteImpl.IsEnabled(), 'Deletion discovery must honor the company switch.');

        // [WHEN] Each message implementation is called directly: this API has no page action.
        // [THEN] Setup refusal precedes parsing, licensing and every tracking write.
        AssertDisabledResponse(false, LanguageId);
        AssertDisabledResponse(true, LanguageId);
        Assert.AreEqual(ReservationCount, ReservationEntry.Count(), 'Disabled calls create or remove no reservation rows.');
        Assert.AreEqual(SpecificationCount, TrackingSpecification.Count(), 'Disabled calls change no specifications.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertDisabledResponse(DeleteMode: Boolean; LanguageId: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        AssignImpl: Codeunit "Tracking Assign Impl ori";
        DeleteImpl: Codeunit "Tracking Delete Impl ori";
        Response: JsonObject;
        Request: JsonObject;
        Token: JsonToken;
        SetupName: Text;
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        if DeleteMode then
            DeleteImpl.ExecuteBifrostTask(TempArgument)
        else
            AssignImpl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Error');
        Assert.IsTrue(Response.Get('code', Token), 'Coded setup refusal is required.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Well-formed operations cannot run while company setup is off.');
        if LanguageId = 1039 then
            SetupName := 'uppsetning'
        else
            SetupName := 'inventory setup';
        Assert.IsTrue(Response.Get('error', Token), 'Setup refusal must explain the error.');
        Assert.IsTrue(StrPos(LowerCase(Token.AsValue().AsText()), SetupName) > 0, 'Error names the company setup in the requested language.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'Setup refusal must explain recovery.');
        Assert.IsTrue(StrPos(LowerCase(Token.AsValue().AsText()), SetupName) > 0, 'Recovery names the setup in the requested language.');
        if LanguageId = 1039 then
            Assert.IsTrue(StrPos(Token.AsValue().AsText(), 'kveikja') > 0, 'Icelandic recovery explains how to enable the domain.')
        else
            Assert.IsTrue(StrPos(Token.AsValue().AsText(), 'turn the domain on') > 0, 'English recovery explains how to enable the domain.');
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
