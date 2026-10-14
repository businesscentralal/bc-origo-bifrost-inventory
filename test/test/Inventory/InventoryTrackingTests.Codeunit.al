namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Finance.Dimension;
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

    /// <summary>Native assembly output tracking is assigned and removed on its own source.</summary>
    [Test]
    procedure AssemblyOutputTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        Header: Record "Assembly Header";
        LibraryAssembly: Codeunit "Library - Assembly";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), PurchaseLine."No.", '', 10, '');

        AssertTrackingRoundTrip(GenericSource('AssemblyHeader', Header.SystemId), Database::"Assembly Header", Header."No.", 0, true);
    end;

    /// <summary>Journal tracking stages native pending tracking without writing persistent Tracking Specification rows.</summary>
    [Test]
    procedure ItemJournalTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", PurchaseLine."No.", 10);

        AssertTrackingRoundTrip(GenericSource('ItemJournalLine', Line.SystemId), Database::"Item Journal Line", JournalTemplate.Name, Line."Line No.", true);
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

    /// <summary>Assembly component tracking belongs to the component line and preserves posted supply.</summary>
    [Test]
    procedure AssemblyComponentTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        ParentItem: Record Item;
        Header: Record "Assembly Header";
        Line: Record "Assembly Line";
        LibraryAssembly: Codeunit "Library - Assembly";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 10);
        LibraryInventory.CreateItem(ParentItem);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), ParentItem."No.", '', 10, '');
        LibraryAssembly.CreateAssemblyLine(Header, Line, Line.Type::Item, PurchaseLine."No.", PurchaseLine."Unit of Measure Code", 10, 1, '');

        AssertTrackingRoundTrip(GenericSource('AssemblyLine', Line.SystemId), Database::"Assembly Line", Line."Document No.", Line."Line No.", false);
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

    /// <summary>Sales returns carry positive pending tracking and remove only that source assignment.</summary>
    [Test]
    procedure SalesReturnTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        LibrarySales: Codeunit "Library - Sales";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::"Return Order", '');
        LibrarySales.CreateSalesLine(Line, Header, Line.Type::Item, PurchaseLine."No.", 10);

        AssertTrackingRoundTrip(GenericSource('SalesLine', Line.SystemId), Database::"Sales Line", Line."Document No.", Line."Line No.", true);
    end;

    /// <summary>Purchase returns carry negative tracking against owned posted stock.</summary>
    [Test]
    procedure PurchaseReturnTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        Header: Record "Purchase Header";
        Line: Record "Purchase Line";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 10);
        LibraryPurchase.CreatePurchHeader(Header, Header."Document Type"::"Return Order", PurchaseLine."Buy-from Vendor No.");
        LibraryPurchase.CreatePurchaseLine(Line, Header, Line.Type::Item, PurchaseLine."No.", 10);

        AssertTrackingRoundTrip(GenericSource('PurchaseLine', Line.SystemId), Database::"Purchase Line", Line."Document No.", Line."Line No.", false);
    end;

    /// <summary>Negative adjustments retain posted stock while pending tracking is assigned and removed.</summary>
    [Test]
    procedure NegativeAdjustmentTrackingRoundTrip()
    var
        PurchaseLine: Record "Purchase Line";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        CreatePurchaseLine(PurchaseLine, false);
        PostTrackedReceipt(PurchaseLine, 10);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Negative Adjmt.", PurchaseLine."No.", 10);

        AssertTrackingRoundTrip(GenericSource('ItemJournalLine', Line.SystemId), Database::"Item Journal Line", JournalTemplate.Name, Line."Line No.", false);
    end;

    /// <summary>Inbound transfer tracking preserves the independent outbound source side.</summary>
    [Test]
    procedure TransferInboundTrackingRoundTrip()
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
        Source.Add('transferDirection', 'Inbound');

        AssertTrackingRoundTrip(Source, Database::"Transfer Line", Line."Document No.", Line."Line No.", true);
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

        ExecuteTracking(Request, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Only pending purchase tracking was removed.');
        Ledger.CalcSums(Quantity);
        Assert.AreEqual(4, Ledger.Quantity, 'Deleting pending tracking cannot change posted inventory.');
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
        EntryNo: Integer;
        Token: JsonToken;
        Row: JsonObject;
        Rows: JsonArray;
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
        EntryNo := Entry."Entry No.";
        DeleteRequest.Add('source', Source);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(DeleteRequest);
        TrackingRead.ReadTracking(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('trackingLines', Token);
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'Source read returns only its pending tracking side.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Row.Get('lotNo', Token);
        Assert.AreEqual('ROUND-LOT', Token.AsValue().AsText(), 'Source read retains the native lot.');
        Row.Get('quantityBase', Token);
        Assert.AreEqual(Entry."Quantity (Base)", Token.AsValue().AsDecimal(), 'Source read retains signed base quantity.');
        Assert.IsTrue(Entry.Get(EntryNo, Positive), 'Reading the source cannot remove its pending entry.');

        ExecuteTracking(DeleteRequest, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Pending tracking was removed on the selected source.');
    end;

    /// <summary>Actual public Help examples assign, read and delete only independently seeded source tracking.</summary>
    [Test]
    procedure Scenario_AC1_PublicExamples_AssignReadDeleteOwnedTracking()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Specification: Record "Tracking Specification";
        Ledger: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        SpecificationCount: Integer;
        LedgerCount: Integer;
    begin
        // Issues #5/#37 | Time: WorkDate from owned fixtures | Risk: examples compile but do not execute.
        // Native layer only: licensed MCP remains blocked by #95; no shipping gate is bypassed.
        CreatePurchaseLine(PurchaseLine, false);
        CreatePurchaseLine(OtherLine, false);
        ExecuteTracking(AssignmentRequest(OtherLine, 'OTHER-LOT', '', 1), false, Response);
        AssertStatus(Response, 'Success');
        SpecificationCount := Specification.Count();
        LedgerCount := Ledger.Count();
        Request := PublishedExampleData("Message Type ori"::"Inventory.Tracking.Assign");
        Request.Replace('source', SourceObject(PurchaseLine));
        ExecuteTracking(Request, false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, Entry);
        Assert.AreEqual(1, Entry.Count(), 'One native tracking row.');
        Entry.FindFirst();
        Assert.AreEqual('OWNED-LOT', Entry."Lot No.", 'Published lot is assigned.');
        Assert.AreEqual(2, Entry."Quantity (Base)", 'Published base quantity is assigned.');
        Request := PublishedExampleData("Message Type ori"::"Inventory.Tracking.Get");
        Request.Replace('source', SourceObject(PurchaseLine));
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        TrackingRead.ReadTracking(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('trackingLines', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Only the selected line is read.');
        Token.AsArray().Get(0, Token);
        Row := Token.AsObject();
        Row.Get('lotNo', Token);
        Assert.AreEqual('OWNED-LOT', Token.AsValue().AsText(), 'Read example sees assigned tracking.');
        Request := PublishedExampleData("Message Type ori"::"Inventory.Tracking.Delete");
        Request.Replace('source', SourceObject(PurchaseLine));
        ExecuteTracking(Request, true, Response);
        AssertStatus(Response, 'Success');
        Assert.IsTrue(Entry.IsEmpty(), 'Owned source tracking is removed.');
        FilterSourceEntries(OtherLine, Entry);
        Assert.AreEqual(1, Entry.Count(), 'Unrelated source is unchanged.');
        Assert.AreEqual(SpecificationCount, Specification.Count(), 'No persistent tracking specification writes.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'No posting occurs.');
    end;

    local procedure PublishedExampleData(MessageType: Enum "Message Type ori") Data: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Example: JsonObject;
        Request: JsonObject;
        Token: JsonToken;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Registered public Help exists.');
        Contract.Get('examples', Token);
        Token.AsArray().Get(0, Token);
        Example := Token.AsObject();
        Example.Get('request', Token);
        Request := Token.AsObject();
        Request.Get('data', Token);
        Data := Token.AsObject();
    end;

    /// <summary>Lot tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_LotReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, false, false, false);
    end;

    /// <summary>Serial tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_SerialReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, true, false, false);
    end;

    /// <summary>Package tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_PackageReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, false, true, false);
    end;

    /// <summary>LotSerial tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_LotSerialReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, true, false, false);
    end;

    /// <summary>LotPackage tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_LotPackageReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, false, true, false);
    end;

    /// <summary>SerialPackage tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_SerialPackageReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, true, true, false);
    end;

    /// <summary>LotSerialPackage tracking survives native receipt with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC37_LotSerialPackageReceiptPreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, true, true, false);
    end;

    /// <summary>Lot tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_LotReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, false, false, true);
    end;

    /// <summary>Serial tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_SerialReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, true, false, true);
    end;

    /// <summary>Package tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_PackageReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, false, true, true);
    end;

    /// <summary>LotSerial tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_LotSerialReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, true, false, true);
    end;

    /// <summary>LotPackage tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_LotPackageReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, false, true, true);
    end;

    /// <summary>SerialPackage tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_SerialPackageReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(false, true, true, true);
    end;

    /// <summary>LotSerialPackage tracking survives native reserve with owned location, variant and dimensions.</summary>
    [Test]
    procedure Scenario_AC7_LotSerialPackageReservePreservesNativeIdentity()
    begin
        VerifyTrackedCombination(true, true, true, true);
    end;

    local procedure VerifyTrackedCombination(UseLot: Boolean; UseSerial: Boolean; UsePackage: Boolean; ReserveAfterPosting: Boolean)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Variant: Record "Item Variant";
        ItemUOM: Record "Item Unit of Measure";
        Location: Record Location;
        DimensionValue: Record "Dimension Value";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Opposite: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryDimension: Codeunit "Library - Dimension";
        LibrarySales: Codeunit "Library - Sales";
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
        Request: JsonObject;
        Response: JsonObject;
        Tracking: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
        LotNo: Code[50];
        SerialNo: Code[50];
        PackageNo: Code[50];
        BaseQuantity: Decimal;
        DimensionSetId: Integer;
        PairNo: Integer;
    begin
        // Issues #5/#7/#37: native integration, not licensed MCP or independent-session contention.
        // Every fixture is created here. Native posting alone creates protected ledger entries.
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode.Validate("Lot Specific Tracking", UseLot);
        TrackingCode.Validate("SN Specific Tracking", UseSerial);
        TrackingCode.Validate("Package Specific Tracking", UsePackage);
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryInventory.CreateItemVariant(Variant, Item."No.");
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        LibraryDimension.CreateDimWithDimValue(DimensionValue);
        DimensionSetId := LibraryDimension.CreateDimSet(0, DimensionValue."Dimension Code", DimensionValue.Code);
        BaseQuantity := 1;
        if not UseSerial then begin
            BaseQuantity := 3;
            LibraryInventory.CreateItemUnitOfMeasureCode(ItemUOM, Item."No.", BaseQuantity);
        end;
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 1);
        PurchaseLine.Validate("Location Code", Location.Code);
        PurchaseLine.Validate("Variant Code", Variant.Code);
        if not UseSerial then
            PurchaseLine.Validate("Unit of Measure Code", ItemUOM.Code);
        PurchaseLine.Validate("Dimension Set ID", DimensionSetId);
        PurchaseLine.Modify(true);
        if UseLot then
            LotNo := 'W8-COMB-LOT';
        if UseSerial then
            SerialNo := 'W8-COMB-SERIAL';
        if UsePackage then
            PackageNo := 'W8-COMB-PACKAGE';
        Tracking.Add('lotNo', LotNo);
        Tracking.Add('serialNo', SerialNo);
        Tracking.Add('packageNo', PackageNo);
        Tracking.Add('quantity', BaseQuantity);
        Entries.Add(Tracking);
        Request.Add('source', SourceObject(PurchaseLine));
        Request.Add('entries', Entries);
        ExecuteTracking(Request, false, Response);
        AssertStatus(Response, 'Success');
        FilterSourceEntries(PurchaseLine, Entry);
        Assert.AreEqual(1, Entry.Count(), 'All tracking dimensions belong to the same pending row.');
        Entry.FindFirst();
        Assert.AreEqual(LotNo, Entry."Lot No.", 'Pending lot identity.');
        Assert.AreEqual(SerialNo, Entry."Serial No.", 'Pending serial identity.');
        Assert.AreEqual(PackageNo, Entry."Package No.", 'Pending package identity.');
        Assert.AreEqual(BaseQuantity, Entry."Quantity (Base)", 'Assignment quantity is in base units.');

        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        Ledger.SetRange("Item No.", Item."No.");
        Assert.AreEqual(1, Ledger.Count(), 'Exactly one native receipt entry.');
        Ledger.FindFirst();
        Assert.AreEqual(LotNo, Ledger."Lot No.", 'Posted lot identity.');
        Assert.AreEqual(SerialNo, Ledger."Serial No.", 'Posted serial identity.');
        Assert.AreEqual(PackageNo, Ledger."Package No.", 'Posted package identity.');
        Assert.AreEqual(Location.Code, Ledger."Location Code", 'Posted location identity.');
        Assert.AreEqual(Variant.Code, Ledger."Variant Code", 'Posted variant identity.');
        Assert.AreEqual(DimensionSetId, Ledger."Dimension Set ID", 'Posting preserves the source dimensions.');
        Assert.AreEqual(BaseQuantity, Ledger."Remaining Quantity", 'Only the assigned base quantity was received.');
        AssertCombinationAvailability(Ledger, 0);
        if not ReserveAfterPosting then
            exit;

        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine.Validate("Location Code", Location.Code);
        SalesLine.Validate("Variant Code", Variant.Code);
        if not UseSerial then
            SalesLine.Validate("Unit of Measure Code", ItemUOM.Code);
        SalesLine.Validate("Dimension Set ID", DimensionSetId);
        SalesLine.Modify(true);
        Clear(Request);
        Request.Add('source', GenericSource('SalesLine', SalesLine.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 1);
        Request.Add('lotNo', LotNo);
        Request.Add('serialNo', SerialNo);
        Request.Add('packageNo', PackageNo);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        ReservationWrite.Run(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        PairNo := Token.AsValue().AsInteger();
        Entry.Get(PairNo, false);
        Opposite.Get(PairNo, true);
        Assert.AreEqual(LotNo, Entry."Lot No.", 'Demand retains selected lot.');
        Assert.AreEqual(SerialNo, Entry."Serial No.", 'Demand retains selected serial.');
        Assert.AreEqual(PackageNo, Entry."Package No.", 'Demand retains selected package.');
        Assert.AreEqual(LotNo, Opposite."Lot No.", 'Supply retains selected lot.');
        Assert.AreEqual(SerialNo, Opposite."Serial No.", 'Supply retains selected serial.');
        Assert.AreEqual(PackageNo, Opposite."Package No.", 'Supply retains selected package.');
        Assert.AreEqual(-BaseQuantity, Entry."Quantity (Base)", 'Demand reserves exact base quantity.');
        Assert.AreEqual(BaseQuantity, Opposite."Quantity (Base)", 'Supply balances the demand.');
        Assert.AreEqual(Ledger."Entry No.", Opposite."Source Ref. No.", 'Only the selected posted supply is paired.');
        AssertCombinationAvailability(Ledger, BaseQuantity);
        Clear(Request);
        Request.Add('source', GenericSource('SalesLine', SalesLine.SystemId));
        Request.Add('entryNo', PairNo);
        TempArgument.SetRequestJson(Request);
        Clear(ReservationWrite);
        ReservationWrite.SetCancelMode();
        ReservationWrite.Run(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Ledger.Get(Ledger."Entry No.");
        Ledger.CalcFields("Reserved Quantity");
        Assert.AreEqual(0, Ledger."Reserved Quantity", 'Cancellation releases the selected supply.');
        Assert.AreEqual(BaseQuantity, Ledger."Remaining Quantity", 'Cancellation never alters posted inventory.');
        AssertCombinationAvailability(Ledger, 0);
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Assert.AreEqual(DimensionSetId, SalesLine."Dimension Set ID", 'Reservation does not change source dimensions.');
    end;

    local procedure AssertCombinationAvailability(Ledger: Record "Item Ledger Entry"; ExpectedReserved: Decimal)
    var
        Entries: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        Token: JsonToken;
        EntryCount: Integer;
    begin
        EntryCount := Entries.Count();
        Request.Add('itemNo', Ledger."Item No.");
        Request.Add('locationFilter', Ledger."Location Code");
        Request.Add('variantCode', Ledger."Variant Code");
        Request.Add('lotNo', Ledger."Lot No.");
        Request.Add('serialNo', Ledger."Serial No.");
        Request.Add('packageNo', Ledger."Package No.");
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);

        TrackingRead.ReadAvailability(TempArgument);

        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('availability', Token);
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'Owned filters identify exactly one tracking combination.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        Row.Get('lotNo', Token);
        Assert.AreEqual(Ledger."Lot No.", Token.AsValue().AsText(), 'Read preserves the lot.');
        Row.Get('serialNo', Token);
        Assert.AreEqual(Ledger."Serial No.", Token.AsValue().AsText(), 'Read preserves the serial.');
        Row.Get('packageNo', Token);
        Assert.AreEqual(Ledger."Package No.", Token.AsValue().AsText(), 'Read preserves the package.');
        Row.Get('locationCode', Token);
        Assert.AreEqual(Ledger."Location Code", Token.AsValue().AsText(), 'Read preserves the location.');
        Row.Get('variantCode', Token);
        Assert.AreEqual(Ledger."Variant Code", Token.AsValue().AsText(), 'Read preserves the variant.');
        Row.Get('inventory', Token);
        Assert.AreEqual(Ledger."Remaining Quantity", Token.AsValue().AsDecimal(), 'Read uses posted base inventory.');
        Row.Get('qtyReserved', Token);
        Assert.AreEqual(ExpectedReserved, Token.AsValue().AsDecimal(), 'Read follows native reservation and cancellation.');
        Row.Get('availableQuantity', Token);
        Assert.AreEqual(Ledger."Remaining Quantity" - ExpectedReserved, Token.AsValue().AsDecimal(), 'Available stock is net of the native pair.');
        Assert.AreEqual(EntryCount, Entries.Count(), 'Reading does not create or delete reservation entries.');
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
