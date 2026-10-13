namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 5 and 7 native read acceptance using isolated, self-created document tracking.</summary>
codeunit 96927 "Inventory Tracking Read Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";

    /// <summary>A document read returns its native tracking and preserves all source records.</summary>
    [Test]
    procedure Scenario_AC1_DocumentKeysReadOnlyOwnTracking()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Specification: Record "Tracking Specification";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        EntryCount: Integer;
        SpecificationCount: Integer;
    begin
        // [GIVEN] Two independently tracked purchase lines.
        CreateTrackedLine(PurchaseLine, 'READ-LOT-A', '', '', 2);
        CreateTrackedLine(OtherLine, 'READ-LOT-B', '', '', 3);
        EntryCount := Entry.Count();
        SpecificationCount := Specification.Count();
        Request := DocumentRequest(PurchaseLine);

        // [WHEN] The first source is read by its document keys.
        ExecuteRead(Request, 0, Response);

        // [THEN] Exactly its own lot is returned, with no writes.
        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', 'READ-LOT-A');
        AssertText(Row, 'sourceType', 'PurchaseLine');
        AssertText(Row, 'documentNo', PurchaseLine."Document No.");
        AssertDecimal(Row, 'quantityBase', 2);
        Assert.AreEqual(EntryCount, Entry.Count(), 'Reads never write reservation entries.');
        Assert.AreEqual(SpecificationCount, Specification.Count(), 'Reads never write tracking specifications.');
    end;

    /// <summary>Line SystemId and document keys resolve the same native source pointer.</summary>
    [Test]
    procedure Scenario_AC1_SystemIdMatchesDocumentKeys()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Source: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-ID', '', '', 2);
        Source.Add('type', 'PurchaseLine');
        Source.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Request.Add('source', Source);

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', 'READ-ID');
        Clear(Request);
        Request.Add('documentType', 'Purchase.Order');
        Request.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        ExecuteRead(Request, 0, Response);
        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', 'READ-ID');
    end;

    /// <summary>A line SystemId supplied as subject selects the document before item resolution.</summary>
    [Test]
    procedure Scenario_AC1_SubjectLineGuidReadsTracking()
    var
        PurchaseLine: Record "Purchase Line";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-SUBJECT', '', '', 2);
        InitArgument(TempArgument, Request);
        TempArgument.Subject := Format(PurchaseLine.SystemId, 0, 4);

        TrackingRead.ReadTracking(TempArgument);

        Response := TempArgument.GetResponseJson();
        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', 'READ-SUBJECT');
        AssertText(Response, 'documentType', 'Purchase.Order');
    end;

    /// <summary>All tracking dimensions, including package-only data, remain visible in reads.</summary>
    [Test]
    procedure Scenario_AC2_PackageAndSerialAreNotLost()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, '', 'READ-SERIAL', 'READ-PACKAGE', 1);
        Request := DocumentRequest(PurchaseLine);
        Request.Add('serialNo', 'READ-SERIAL');
        Request.Add('packageNo', 'READ-PACKAGE');

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'serialNo', 'READ-SERIAL');
        AssertText(Row, 'packageNo', 'READ-PACKAGE');
        AssertDecimal(Row, 'quantityBase', 1);
    end;

    /// <summary>Item SystemId resolves pending tracking independently from document identity.</summary>
    [Test]
    procedure Scenario_AC2_ItemSystemIdReadsPendingTracking()
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-ITEM', '', '', 2);
        Item.Get(PurchaseLine."No.");
        Request.Add('itemId', Format(Item.SystemId, 0, 4));

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'itemNo', Item."No.");
        AssertText(Row, 'lotNo', 'READ-ITEM');
    end;

    /// <summary>Missing document lines produce a structured error without falling back to unrelated item records.</summary>
    [Test]
    procedure Scenario_AC3_UnknownDocumentReturnsError()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('documentType', 'Purchase.Order');
        Request.Add('documentNo', CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
        Request.Add('lineNo', 10000);

        ExecuteRead(Request, 0, Response);

        AssertText(Response, 'status', 'Error');
    end;

    /// <summary>Malformed tracking filters and fractional paging never silently broaden reads.</summary>
    [Test]
    procedure Scenario_AC3_InvalidFilterAndPagingReturnError()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-INVALID', '', '', 2);
        Request := DocumentRequest(PurchaseLine);
        Request.Add('lotNo', 12);
        ExecuteRead(Request, 0, Response);
        AssertText(Response, 'status', 'Error');
        Request.Remove('lotNo');
        Request.Add('skip', 0.5);
        ExecuteRead(Request, 0, Response);
        AssertText(Response, 'status', 'Error');
    end;

    /// <summary>Item paging slices a deterministic tracking sequence and reports total versus returned counts.</summary>
    [Test]
    procedure Scenario_AC8_PagingPreservesTotalAndOrder()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-FIRST', '', '', 2);
        AssignTracking(PurchaseLine, 'READ-SECOND', '', '', 3);
        Request.Add('itemNo', PurchaseLine."No.");
        Request.Add('skip', 1);
        Request.Add('take', 1);

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        AssertDecimal(Response, 'noOfLines', 1);
        AssertDecimal(Response, 'totalNoOfLines', 2);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', 'READ-SECOND');
        Request.Replace('skip', 5);
        ExecuteRead(Request, 0, Response);
        AssertSuccess(Response);
        AssertDecimal(Response, 'noOfLines', 0);
        AssertDecimal(Response, 'totalNoOfLines', 2);
    end;

    /// <summary>Reservation reads return stable source names and apply filters before deciding whether an entry exists.</summary>
    [Test]
    procedure Scenario_AC7_ReservationFiltersIntersectBeforeLookup()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-RESERVATION', '', '', 2);
        Request := DocumentRequest(PurchaseLine);
        ExecuteRead(Request, 1, Response);
        AssertSuccess(Response);
        Row := SingleRow(Response, 'entries');
        AssertText(Row, 'sourceType', 'PurchaseLine');
        AssertText(Row, 'documentNo', PurchaseLine."Document No.");
        AssertDecimal(Row, 'lineNo', PurchaseLine."Line No.");
        Row.Get('entryNo', Token);
        Request.Add('entryNo', Token);
        Request.Add('lotNo', 'DIFFERENT-LOT');

        ExecuteRead(Request, 1, Response);

        AssertText(Response, 'status', 'Error');
    end;

    /// <summary>Supplying both location syntax forms intersects them instead of overriding a requested filter.</summary>
    [Test]
    procedure Scenario_AC2_LocationCodeDoesNotOverrideFilter()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-LOCATION', '', '', 2);
        Request := DocumentRequest(PurchaseLine);
        Request.Add('locationFilter', 'NOT-OURS');
        Request.Add('locationCode', '');

        ExecuteRead(Request, 0, Response);

        AssertText(Response, 'status', 'Error');
    end;

    /// <summary>Two posted receipts with the same tracking dimensions are aggregated, rather than exposed as ledger rows.</summary>
    [Test]
    procedure Scenario_AC4_AvailabilityGroupsPostedReceipts()
    var
        PurchaseLine: Record "Purchase Line";
        SecondLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-STOCK', '', '', 2);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        PurchaseLine.Validate("Qty. to Receive", 2);
        PurchaseLine.Modify(true);
        LibraryPurchase.CreatePurchaseLine(SecondLine, PurchaseHeader, SecondLine.Type::Item, PurchaseLine."No.", 3);
        AssignTracking(SecondLine, 'READ-STOCK', '', '', 3);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        Request.Add('itemNo', PurchaseLine."No.");
        Request.Add('lotNo', 'READ-STOCK');

        ExecuteRead(Request, 2, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'availability');
        AssertDecimal(Row, 'inventory', 5);
        AssertDecimal(Row, 'qtyReserved', 0);
        AssertDecimal(Row, 'availableQuantity', 5);
        AssertText(Row, 'expirationDate', '');
    end;

    /// <summary>Availability subtracts the native reserved quantity only from the matching posted tracking position.</summary>
    [Test]
    procedure Scenario_AC4_AvailabilitySubtractsNativeReservation()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LibrarySales: Codeunit "Library - Sales";
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
        Request: JsonObject;
        Source: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-RESERVED', '', '', 2);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        PurchaseLine.Validate("Qty. to Receive", 2);
        PurchaseLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        Ledger.SetRange("Item No.", PurchaseLine."No.");
        Ledger.FindLast();
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, PurchaseLine."No.", 2);
        Source.Add('type', 'SalesLine');
        Source.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        Request.Add('source', Source);
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 1);
        InitArgument(TempArgument, Request);
        ReservationWrite.Run(TempArgument);
        AssertSuccess(TempArgument.GetResponseJson());
        Clear(Request);
        Request.Add('itemNo', PurchaseLine."No.");
        Request.Add('lotNo', 'READ-RESERVED');

        ExecuteRead(Request, 2, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'availability');
        AssertDecimal(Row, 'inventory', 2);
        AssertDecimal(Row, 'qtyReserved', 1);
        AssertDecimal(Row, 'availableQuantity', 1);
    end;

    /// <summary>Native entry fallback is returned as ISO text; master precedence has separate pending schema acceptance.</summary>
    [Test]
    procedure Scenario_AC5_TrackingEntryExpirationIsPreserved()
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-NODATE', '', '', 1);
        Item.Get(PurchaseLine."No.");
        TrackingCode.Get(Item."Item Tracking Code");
        TrackingCode.Validate("Use Expiration Dates", true);
        TrackingCode.Modify(true);
        AssignTrackingWithExpiration(PurchaseLine, 'READ-DATED', '', '', 1, 20310101D);
        Request := DocumentRequest(PurchaseLine);
        Request.Add('lotNo', 'READ-DATED');

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'expirationDate', '2031-01-01');
    end;

    /// <summary>A package-only source does not need a fabricated lot or serial to be returned.</summary>
    [Test]
    procedure Scenario_AC2_PackageOnlyTrackingIsVisible()
    var
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, '', '', 'READ-PACKAGE-ONLY', 2);
        Request := DocumentRequest(PurchaseLine);

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'lotNo', '');
        AssertText(Row, 'serialNo', '');
        AssertText(Row, 'packageNo', 'READ-PACKAGE-ONLY');
        AssertDecimal(Row, 'quantityBase', 2);
    end;

    /// <summary>Disabled master expiration policy falls back to the native pending entry date without changing it.</summary>
    [Test]
    procedure Scenario_AC5_DisabledPolicyFallsBackToEntryDate()
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-NODATE-OFF', '', '', 1);
        Item.Get(PurchaseLine."No.");
        TrackingCode.Get(Item."Item Tracking Code");
        TrackingCode.Validate("Use Expiration Dates", true);
        TrackingCode.Modify(true);
        AssignTrackingWithExpiration(PurchaseLine, 'READ-DATED-OFF', '', '', 1, 20310101D);
        TrackingCode.Validate("Use Expiration Dates", false);
        TrackingCode.Modify(true);
        Request := DocumentRequest(PurchaseLine);
        Request.Add('lotNo', 'READ-DATED-OFF');

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'expirationDate', '2031-01-01');
        Entry.SetRange("Item No.", PurchaseLine."No.");
        Entry.SetRange("Lot No.", 'READ-DATED-OFF');
        Entry.FindFirst();
        Assert.AreEqual(20310101D, Entry."Expiration Date", 'Projection must not erase the native date.');
    end;

    /// <summary>A conflicting native lot/package date is blanked in one group and never guessed or split into date groups.</summary>
    [Test]
    procedure Scenario_AC5_GroupedDateDisagreementReturnsBlank()
    var
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        // Defensive projection test: BC normally keeps lot dates consistent. Never corrupt posted ledger data to manufacture this condition.
        AddTemporaryStock(TempLedger, 1, 20310101D);
        AddTemporaryStock(TempLedger, 2, 20310201D);
        AddTemporaryStock(TempLedger, 3, 20310101D);

        TrackingRead.AggregateAvailability(TempLedger, Rows);

        Assert.AreEqual(1, Rows.Count(), 'Date disagreement must not split a tracking group.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        AssertText(Row, 'expirationDate', '');
        AssertDecimal(Row, 'inventory', 6);
    end;

    /// <summary>Matching entry dates are exposed; undated native stock returns blank, never a zero-date string.</summary>
    [Test]
    procedure Scenario_AC5_GroupedEntryDateAndUndatedFallback()
    var
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        AddTemporaryStock(TempLedger, 1, 20310101D);
        AddTemporaryStock(TempLedger, 2, 20310101D);
        TrackingRead.AggregateAvailability(TempLedger, Rows);
        Assert.AreEqual(1, Rows.Count(), 'Matching native positions form one group.');
        Rows.Get(0, Token);
        AssertText(Token.AsObject(), 'expirationDate', '2031-01-01');
        TempLedger.DeleteAll();
        AddTemporaryStock(TempLedger, 1, 0D);
        AddTemporaryStock(TempLedger, 2, 0D);

        TrackingRead.AggregateAvailability(TempLedger, Rows);

        Rows.Get(0, Token);
        Row := Token.AsObject();
        AssertText(Row, 'expirationDate', '');
        AssertDecimal(Row, 'inventory', 4);
    end;

    /// <summary>Explicit serial/package selection survives native posted supply and both reservation sides.</summary>
    [Test]
    procedure Scenario_AC4_ReservationCarriesSerialAndPackage()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        LibrarySales: Codeunit "Library - Sales";
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
        Request: JsonObject;
        Source: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateTrackedLine(PurchaseLine, '', 'RES-SERIAL', 'RES-PACKAGE', 1);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        PurchaseLine.Validate("Qty. to Receive", 1);
        PurchaseLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        Ledger.SetRange("Item No.", PurchaseLine."No.");
        Ledger.FindLast();
        Assert.AreEqual('RES-SERIAL', Ledger."Serial No.", 'Fixture uses genuinely posted serial supply.');
        Assert.AreEqual('RES-PACKAGE', Ledger."Package No.", 'Fixture uses genuinely posted package supply.');
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, PurchaseLine."No.", 1);
        Source.Add('type', 'SalesLine');
        Source.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        Request.Add('source', Source);
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 1);
        Request.Add('serialNo', 'RES-SERIAL');
        Request.Add('packageNo', 'RES-PACKAGE');
        InitArgument(TempArgument, Request);

        ReservationWrite.Run(TempArgument);

        Response := TempArgument.GetResponseJson();
        AssertSuccess(Response);
        Response.Get('entryNo', Token);
        Entry.SetRange("Entry No.", Token.AsValue().AsInteger());
        Assert.AreEqual(2, Entry.Count(), 'Both native reservation sides exist.');
        Entry.FindSet();
        repeat
            Assert.AreEqual('RES-SERIAL', Entry."Serial No.", 'Requested serial is preserved on both sides.');
            Assert.AreEqual('RES-PACKAGE', Entry."Package No.", 'Requested package is preserved on both sides.');
            Assert.AreEqual(1, Abs(Entry."Quantity (Base)"), 'Exactly one base unit is reserved for the serial.');
        until Entry.Next() = 0;
    end;

    local procedure AddTemporaryStock(var TempLedger: Record "Item Ledger Entry" temporary; EntryNo: Integer; ExpirationDate: Date)
    begin
        Assert.IsTrue(TempLedger.IsTemporary(), 'Defensive inconsistent-date inputs must stay in memory.');
        TempLedger.Init();
        TempLedger."Entry No." := EntryNo;
        TempLedger."Item No." := 'W8-TEMP';
        TempLedger."Lot No." := 'W8-TEMP-LOT';
        TempLedger."Package No." := 'W8-TEMP-PACKAGE';
        TempLedger."Remaining Quantity" := 2;
        TempLedger.Open := true;
        TempLedger.Positive := true;
        TempLedger."Expiration Date" := ExpirationDate;
        TempLedger.Insert();
    end;

    local procedure CreateTrackedLine(var PurchaseLine: Record "Purchase Line"; Lot: Text; Serial: Text; Package: Text; Quantity: Decimal)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        PurchaseHeader: Record "Purchase Header";
    begin
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode."Lot Specific Tracking" := Lot <> '';
        TrackingCode."SN Specific Tracking" := Serial <> '';
        TrackingCode."Package Specific Tracking" := Package <> '';
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        AssignTracking(PurchaseLine, Lot, Serial, Package, Quantity);
    end;

    local procedure AssignTracking(PurchaseLine: Record "Purchase Line"; Lot: Text; Serial: Text; Package: Text; Quantity: Decimal)
    begin
        AssignTrackingWithExpiration(PurchaseLine, Lot, Serial, Package, Quantity, 0D);
    end;

    local procedure AssignTrackingWithExpiration(PurchaseLine: Record "Purchase Line"; Lot: Text; Serial: Text; Package: Text; Quantity: Decimal; ExpirationDate: Date)
    var
        TempArgument: Record "Message Argument ori" temporary;
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
        Source: JsonObject;
        Request: JsonObject;
        Entry: JsonObject;
        Entries: JsonArray;
    begin
        Source.Add('type', 'PurchaseLine');
        Source.Add('systemId', Format(PurchaseLine.SystemId, 0, 4));
        Request.Add('source', Source);
        Entry.Add('lotNo', Lot);
        Entry.Add('serialNo', Serial);
        Entry.Add('packageNo', Package);
        Entry.Add('quantity', Quantity);
        if ExpirationDate <> 0D then
            Entry.Add('expirationDate', ExpirationDate);
        Entries.Add(Entry);
        Request.Add('entries', Entries);
        InitArgument(TempArgument, Request);
        TrackingWrite.Run(TempArgument);
        AssertSuccess(TempArgument.GetResponseJson());
    end;

    local procedure DocumentRequest(PurchaseLine: Record "Purchase Line") Request: JsonObject
    begin
        Request.Add('documentType', 'Purchase.Order');
        Request.Add('documentNo', PurchaseLine."Document No.");
        Request.Add('lineNo', PurchaseLine."Line No.");
    end;

    local procedure ExecuteRead(Request: JsonObject; Mode: Integer; var Response: JsonObject)
    var
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
    begin
        InitArgument(TempArgument, Request);
        // These native AL tests do not claim shipping license/dispatcher or MCP coverage.
        case Mode of
            0: TrackingRead.ReadTracking(TempArgument);
            1: TrackingRead.ReadReservations(TempArgument);
            2: TrackingRead.ReadAvailability(TempArgument);
        end;
        Response := TempArgument.GetResponseJson();
    end;

    local procedure InitArgument(var Argument: Record "Message Argument ori"; Request: JsonObject)
    begin
        Argument.Init();
        Argument.Version := "Message Version ori"::"1.0";
        Argument.Insert(true);
        Argument.SetRequestJson(Request);
    end;

    local procedure SingleRow(Response: JsonObject; KeyName: Text) Row: JsonObject
    var
        Token: JsonToken;
        Rows: JsonArray;
    begin
        Assert.IsTrue(Response.Get(KeyName, Token), 'Response array is present.');
        Rows := Token.AsArray();
        Assert.AreEqual(1, Rows.Count(), 'Exactly one matching row.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
    end;

    local procedure AssertSuccess(Response: JsonObject)
    begin
        AssertText(Response, 'status', 'Success');
    end;

    local procedure AssertText(Response: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get(KeyName, Token), Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Serialized);
    end;

    local procedure AssertDecimal(Response: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get(KeyName, Token), Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), Serialized);
    end;
}
