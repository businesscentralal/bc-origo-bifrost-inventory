namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 5 native read acceptance using isolated, self-created document tracking.</summary>
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

    /// <summary>The declared Item table view selects only the requested pending tracking.</summary>
    [Test]
    procedure Scenario_AC2_TrackingTableViewReadsOnlySelectedItem()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Item: Record Item;
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        EntryCount: Integer;
    begin
        // Stories #5 AC2 / #30 | Time: native WorkDate fixture | Risk: undocumented Item selector widens tracking reads.
        AssertTableViewParameter("Message Type ori"::"Inventory.Tracking.Get");
        CreateTrackedLine(PurchaseLine, 'XVIEW-SELECTED', '', '', 2);
        CreateTrackedLine(OtherLine, 'XVIEW-OTHER', '', '', 3);
        OtherLine.Validate("Qty. to Receive", 3);
        OtherLine.Modify(true);
        Item.SetRange("No.", PurchaseLine."No.");
        Request.Add('tableView', Item.GetView(true));
        EntryCount := Entry.Count();

        ExecuteRead(Request, 0, Response);

        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'itemNo', PurchaseLine."No.");
        AssertText(Row, 'lotNo', 'XVIEW-SELECTED');
        AssertDecimal(Row, 'quantityBase', 2);
        Assert.AreEqual(EntryCount, Entry.Count(), 'Selecting tracking does not change reservation rows.');
    end;

    /// <summary>The declared Item table view selects only the requested posted stock.</summary>
    [Test]
    procedure Scenario_AC4_AvailabilityTableViewReadsOnlySelectedItem()
    var
        PurchaseLine: Record "Purchase Line";
        OtherLine: Record "Purchase Line";
        Header: Record "Purchase Header";
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        LedgerCount: Integer;
        EntryCount: Integer;
    begin
        // Stories #5 AC4 / #30 | Time: native WorkDate fixture | Risk: undocumented Item selector widens availability reads.
        AssertTableViewParameter("Message Type ori"::"Inventory.TrackingAvailability.Get");
        CreateTrackedLine(PurchaseLine, 'XVIEW-STOCK', '', '', 2);
        PurchaseLine.Validate("Qty. to Receive", 2);
        PurchaseLine.Modify(true);
        Header.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(Header, true, false);
        CreateTrackedLine(OtherLine, 'XVIEW-OTHER', '', '', 3);
        OtherLine.Validate("Qty. to Receive", 3);
        OtherLine.Modify(true);
        Header.Get(OtherLine."Document Type", OtherLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(Header, true, false);
        Item.SetRange("No.", PurchaseLine."No.");
        Request.Add('tableView', Item.GetView(true));
        LedgerCount := Ledger.Count();
        EntryCount := Entry.Count();

        ExecuteRead(Request, 2, Response);

        AssertSuccess(Response);
        AssertText(Response, 'itemNo', PurchaseLine."No.");
        Row := SingleRow(Response, 'availability');
        AssertText(Row, 'lotNo', 'XVIEW-STOCK');
        AssertDecimal(Row, 'inventory', 2);
        AssertDecimal(Row, 'availableQuantity', 2);
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Availability selection does not post stock.');
        Assert.AreEqual(EntryCount, Entry.Count(), 'Availability selection does not change reservations.');
    end;

    /// <summary>Wrong-typed Item table views are refused rather than selecting unrelated tracking.</summary>
    [Test]
    procedure Scenario_AC3_TrackingTableViewWrongTypeIsRefused()
    begin
        // Stories #5 AC3 / #30 | Time: no date dependency | Risk: invalid selection falls back to all items.
        AssertWrongTypedTableView(0);
    end;

    /// <summary>Wrong-typed Item table views are refused rather than selecting unrelated stock.</summary>
    [Test]
    procedure Scenario_AC4_AvailabilityTableViewWrongTypeIsRefused()
    begin
        // Stories #5 AC4 / #30 | Time: no date dependency | Risk: invalid selection falls back to all items.
        AssertWrongTypedTableView(2);
    end;

    local procedure AssertWrongTypedTableView(Mode: Integer)
    var
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        LedgerCount: Integer;
        EntryCount: Integer;
    begin
        LedgerCount := Ledger.Count();
        EntryCount := Entry.Count();
        Request.Add('tableView', 123);
        ExecuteRead(Request, Mode, Response);
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'InvalidParameterFormat');
        AssertText(Response, 'parameter', 'tableView');
        Assert.IsFalse(Response.Contains('trackingLines'), 'Invalid selection returns no tracking.');
        Assert.IsFalse(Response.Contains('availability'), 'Invalid selection returns no availability.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Invalid selection leaves ledger rows unchanged.');
        Assert.AreEqual(EntryCount, Entry.Count(), 'Invalid selection leaves reservation rows unchanged.');
    end;

    local procedure AssertTableViewParameter(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Interface ori";
        Contract: JsonObject;
        Parameter: JsonObject;
        Parameters: JsonArray;
        Token: JsonToken;
        Value: JsonToken;
        Matches: Integer;
    begin
        Implementation := MessageType;
        Assert.AreEqual(Database::Item, Implementation.GetFilterTableNo(), 'Discovery must select Item, matching the declared and implemented tableView.');
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'Tracking contract exists.');
        Assert.IsTrue(Contract.Get('parameters', Token), 'Parameters chapter exists.');
        Parameters := Token.AsArray();
        foreach Token in Parameters do begin
            Parameter := Token.AsObject();
            Parameter.Get('name', Value);
            if Value.AsValue().AsText() = 'tableView' then begin
                Matches += 1;
                AssertText(Parameter, 'type', 'string');
                Parameter.Get('required', Value);
                Assert.IsFalse(Value.AsValue().AsBoolean(), 'Item table view is optional.');
                Parameter.Get('description', Value);
                Assert.IsTrue(Value.AsValue().AsText().Contains('Item table view'), 'Help names the Item table rather than the result table.');
            end;
        end;
        Assert.AreEqual(1, Matches, 'Help declares the consumed tableView exactly once.');
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

    /// <summary>An item read with no source and no item selector is refused instead of reading the first item (#97).</summary>
    [Test]
    procedure Scenario_AC3_NoItemSelectionIsRefused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A request with paging only: no source, no subject and no item selector.
        Request.Add('take', 10);

        // [WHEN] Tracking is read.
        ExecuteRead(Request, 0, Response);

        // [THEN] The read is refused on itemNo and returns no rows.
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'MissingParameter');
        AssertText(Response, 'parameter', 'itemNo');
        Assert.IsFalse(Response.Contains('trackingLines'), 'A refused read returns no tracking.');
    end;

    /// <summary>A blank itemNo is no item selection either (#97).</summary>
    [Test]
    procedure Scenario_AC3_BlankItemNoIsRefused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A request whose only selector is a blank itemNo.
        Request.Add('itemNo', ' ');

        // [WHEN] Tracking is read.
        ExecuteRead(Request, 0, Response);

        // [THEN] The read is refused on itemNo.
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'MissingParameter');
        AssertText(Response, 'parameter', 'itemNo');
    end;

    /// <summary>An existing item with no tracking returns RecordNotFound without changing native rows.</summary>
    [Test]
    procedure Scenario_AC3_UntrackedItemReturnsNotFoundWithoutWrites()
    begin
        AssertUntrackedReadHasNoWrites(false);
    end;

    /// <summary>An existing document line with no tracking returns RecordNotFound without changing native rows.</summary>
    [Test]
    procedure Scenario_AC3_UntrackedDocumentReturnsNotFoundWithoutWrites()
    begin
        AssertUntrackedReadHasNoWrites(true);
    end;

    local procedure AssertUntrackedReadHasNoWrites(ReadDocument: Boolean)
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Entry: Record "Reservation Entry";
        Ledger: Record "Item Ledger Entry";
        Specification: Record "Tracking Specification";
        Request: JsonObject;
        Response: JsonObject;
        EntryCount: Integer;
        LedgerCount: Integer;
        SpecificationCount: Integer;
        ItemModifiedAt: DateTime;
        LineModifiedAt: DateTime;
    begin
        // Story #5 AC03 | Time: independent | Risk: empty reads must not create tracking or modify source records.
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        Item.Get(Item."No.");
        ItemModifiedAt := Item.SystemModifiedAt;
        LineModifiedAt := PurchaseLine.SystemModifiedAt;
        EntryCount := Entry.Count();
        LedgerCount := Ledger.Count();
        SpecificationCount := Specification.Count();
        if ReadDocument then
            Request := DocumentRequest(PurchaseLine)
        else
            Request.Add('itemNo', Item."No.");

        ExecuteRead(Request, 0, Response);

        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', 'RecordNotFound');
        Assert.AreEqual(EntryCount, Entry.Count(), 'Empty read creates no reservation entries.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Empty read creates no ledger entries.');
        Assert.AreEqual(SpecificationCount, Specification.Count(), 'Empty read creates no tracking specifications.');
        Item.Get(Item."No.");
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        Assert.AreEqual(ItemModifiedAt, Item.SystemModifiedAt, 'Empty read leaves the item unchanged.');
        Assert.AreEqual(LineModifiedAt, PurchaseLine.SystemModifiedAt, 'Empty read leaves the document line unchanged.');
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
        LibrarySales: Codeunit "Library - Sales";
        Request: JsonObject;
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
        ReserveOwnedSupply(SalesLine, Ledger, 1);
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

    /// <summary>Enabled expiration policy returns the native entry date as ISO text.</summary>
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

    /// <summary>Disabled expiration policy returns blank without changing the native pending entry date.</summary>
    [Test]
    procedure Scenario_AC5_DisabledPolicyReturnsBlank()
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
        AssertText(Row, 'expirationDate', '');
        Entry.SetRange("Item No.", PurchaseLine."No.");
        Entry.SetRange("Lot No.", 'READ-DATED-OFF');
        Entry.FindFirst();
        Assert.AreEqual(20310101D, Entry."Expiration Date", 'Projection must not erase the native date.');
    end;

    /// <summary>A conflicting native lot/package date is blanked in one group and never guessed or split into date groups.</summary>
    [Test]
    procedure Scenario_AC5_GroupedDateDisagreementReturnsBlank()
    var
        Item: Record Item;
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        CreateAvailabilityItem(Item, true);
        // Defensive projection test: BC normally keeps lot dates consistent. Never corrupt posted ledger data to manufacture this condition.
        AddTemporaryStock(TempLedger, Item."No.", 1, 20310101D);
        AddTemporaryStock(TempLedger, Item."No.", 2, 20310201D);
        AddTemporaryStock(TempLedger, Item."No.", 3, 20310101D);

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
        Item: Record Item;
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
    begin
        CreateAvailabilityItem(Item, true);
        AddTemporaryStock(TempLedger, Item."No.", 1, 20310101D);
        AddTemporaryStock(TempLedger, Item."No.", 2, 20310101D);
        TrackingRead.AggregateAvailability(TempLedger, Rows);
        Assert.AreEqual(1, Rows.Count(), 'Matching native positions form one group.');
        Rows.Get(0, Token);
        AssertText(Token.AsObject(), 'expirationDate', '2031-01-01');
        TempLedger.DeleteAll();
        AddTemporaryStock(TempLedger, Item."No.", 1, 0D);
        AddTemporaryStock(TempLedger, Item."No.", 2, 0D);

        TrackingRead.AggregateAvailability(TempLedger, Rows);

        Rows.Get(0, Token);
        Row := Token.AsObject();
        AssertText(Row, 'expirationDate', '');
        AssertDecimal(Row, 'inventory', 4);
    end;

    /// <summary>A lot containing dated then undated stock has no unambiguous expiration date.</summary>
    [Test]
    procedure Scenario_AC5_LotDatedThenUndatedReturnsBlank()
    begin
        // Story #5, AC5 | Time: fixed entry dates; Today/WorkDate ignored | Risk: temporary inconsistent native state only.
        AssertMixedExpirationGroup(false, false);
    end;

    /// <summary>A lot containing undated then dated stock must not acquire the later entry date.</summary>
    [Test]
    procedure Scenario_AC5_LotUndatedThenDatedReturnsBlank()
    begin
        // Story #5, AC5 | Time: fixed entry dates; Today/WorkDate ignored | Risk: temporary inconsistent native state only.
        AssertMixedExpirationGroup(false, true);
    end;

    /// <summary>A package containing dated then undated stock has no unambiguous expiration date.</summary>
    [Test]
    procedure Scenario_AC5_PackageDatedThenUndatedReturnsBlank()
    begin
        // Story #5, AC5 | Time: fixed entry dates; Today/WorkDate ignored | Risk: temporary inconsistent native state only.
        AssertMixedExpirationGroup(true, false);
    end;

    /// <summary>A package containing undated then dated stock must not acquire the later entry date.</summary>
    [Test]
    procedure Scenario_AC5_PackageUndatedThenDatedReturnsBlank()
    begin
        // Story #5, AC5 | Time: fixed entry dates; Today/WorkDate ignored | Risk: temporary inconsistent native state only.
        AssertMixedExpirationGroup(true, true);
    end;

    local procedure AssertMixedExpirationGroup(PackageOnly: Boolean; UndatedFirst: Boolean)
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
        Row: JsonObject;
        FirstDate: Date;
        SecondDate: Date;
        LedgerCount: Integer;
    begin
        // [GIVEN] Only temporary entries carry the inconsistent date combination; posted ledgers are untouched.
        CreateAvailabilityItem(Item, true);
        LedgerCount := Ledger.Count();
        FirstDate := 20310101D;
        SecondDate := 0D;
        if UndatedFirst then begin
            FirstDate := 0D;
            SecondDate := 20310101D;
        end;
        AddTemporaryStock(TempLedger, Item."No.", 1, FirstDate);
        AddTemporaryStock(TempLedger, Item."No.", 2, SecondDate);
        AddTemporaryStock(TempLedger, Item."No.", 3, 20310101D);
        if PackageOnly then
            TempLedger.ModifyAll("Lot No.", '')
        else
            TempLedger.ModifyAll("Package No.", '');

        // [WHEN] The same native projection aggregates all three positions.
        TrackingRead.AggregateAvailability(TempLedger, Rows);

        // [THEN] Neither encounter order nor a later dated row can invent a group expiration.
        Assert.AreEqual(1, Rows.Count(), 'Mixed dates must not split the tracking group.');
        Rows.Get(0, Token);
        Row := Token.AsObject();
        AssertText(Row, 'expirationDate', '');
        AssertDecimal(Row, 'inventory', 6);
        AssertDecimal(Row, 'availableQuantity', 6);
        AssertDecimal(Row, 'qtyReserved', 0);
        TempLedger.Get(1);
        Assert.AreEqual(FirstDate, TempLedger."Expiration Date", 'Projection preserves the first entry date.');
        TempLedger.Get(2);
        Assert.AreEqual(SecondDate, TempLedger."Expiration Date", 'Projection preserves the second entry date.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Defensive projection must not create posted stock.');
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
        LibrarySales: Codeunit "Library - Sales";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
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
        ReserveOwnedSupply(SalesLine, Ledger, 1);
        Entry.SetRange("Source Type", Database::"Sales Line");
        Entry.SetRange("Source ID", SalesLine."Document No.");
        Entry.SetRange("Source Ref. No.", SalesLine."Line No.");
        Assert.IsTrue(Entry.FindFirst(), 'Owned native demand reservation exists.');
        Entry.SetRange("Entry No.", Entry."Entry No.");
        Entry.SetRange("Source Type");
        Entry.SetRange("Source ID");
        Entry.SetRange("Source Ref. No.");
        Assert.AreEqual(2, Entry.Count(), 'Both native reservation sides exist.');
        Entry.FindSet();
        repeat
            Assert.AreEqual('RES-SERIAL', Entry."Serial No.", 'Requested serial is preserved on both sides.');
            Assert.AreEqual('RES-PACKAGE', Entry."Package No.", 'Requested package is preserved on both sides.');
            Assert.AreEqual(1, Abs(Entry."Quantity (Base)"), 'Exactly one base unit is reserved for the serial.');
        until Entry.Next() = 0;
        Request.Add('itemNo', PurchaseLine."No.");
        Request.Add('serialNo', 'RES-SERIAL');
        Request.Add('packageNo', 'RES-PACKAGE');
        ExecuteRead(Request, 2, Response);
        AssertSuccess(Response);
        Row := SingleRow(Response, 'availability');
        AssertText(Row, 'serialNo', 'RES-SERIAL');
        AssertText(Row, 'packageNo', 'RES-PACKAGE');
        AssertDecimal(Row, 'qtyReserved', 1);
        AssertDecimal(Row, 'availableQuantity', 0);

        // The same owned reservation also proves the Sales document projection, not only item availability.
        Clear(Request);
        Request.Add('documentType', 'Sales.Order');
        Request.Add('documentNo', SalesLine."Document No.");
        Request.Add('lineNo', SalesLine."Line No.");
        ExecuteRead(Request, 0, Response);
        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'sourceType', 'SalesLine');
        AssertText(Row, 'serialNo', 'RES-SERIAL');
        AssertText(Row, 'packageNo', 'RES-PACKAGE');
        AssertDecimal(Row, 'quantityBase', -1);
    end;

    /// <summary>Package-only disagreement stays blank; disabling the policy blanks even matching dates.</summary>
    [Test]
    procedure Scenario_AC5_PackageDisagreementAndDisabledPolicy()
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        TempLedger: Record "Item Ledger Entry" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Rows: JsonArray;
        Token: JsonToken;
    begin
        CreateAvailabilityItem(Item, true);
        AddTemporaryStock(TempLedger, Item."No.", 1, 20310101D);
        AddTemporaryStock(TempLedger, Item."No.", 2, 20310201D);
        TempLedger.ModifyAll("Lot No.", '');
        TrackingRead.AggregateAvailability(TempLedger, Rows);
        Assert.AreEqual(1, Rows.Count(), 'Package-only entries stay in one group.');
        Rows.Get(0, Token);
        AssertText(Token.AsObject(), 'expirationDate', '');
        TempLedger.ModifyAll("Expiration Date", 20310101D);
        TrackingRead.AggregateAvailability(TempLedger, Rows);
        Rows.Get(0, Token);
        AssertText(Token.AsObject(), 'expirationDate', '2031-01-01');
        TrackingCode.Get(Item."Item Tracking Code");
        TrackingCode.Validate("Use Expiration Dates", false);
        TrackingCode.Modify(true);
        TrackingRead.AggregateAvailability(TempLedger, Rows);
        Rows.Get(0, Token);
        AssertText(Token.AsObject(), 'expirationDate', '');
        TempLedger.FindFirst();
        Assert.AreEqual(20310101D, TempLedger."Expiration Date", 'Projection never changes stored dates.');
    end;

    /// <summary>An enabled tracking policy cannot manufacture an expiration date for an undated entry.</summary>
    [Test]
    procedure Scenario_AC5_EnabledUndatedEntryReturnsBlank()
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateTrackedLine(PurchaseLine, 'READ-UNDATED', '', '', 1);
        Item.Get(PurchaseLine."No.");
        TrackingCode.Get(Item."Item Tracking Code");
        TrackingCode.Validate("Use Expiration Dates", true);
        TrackingCode.Modify(true);
        Request := DocumentRequest(PurchaseLine);
        ExecuteRead(Request, 0, Response);
        AssertSuccess(Response);
        AssertText(SingleRow(Response, 'trackingLines'), 'expirationDate', '');
    end;

    /// <summary>The published availability example reads owned posted stock and leaves native records unchanged.</summary>
    [Test]
    procedure Scenario_AC4_PublicAvailabilityExample_ReadsOwnedStock()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Example: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Token: JsonToken;
        LedgerCount: Integer;
        EntryCount: Integer;
    begin
        // Issues #5/#30 | Time: owned native WorkDate | Risk: Help examples return plausible but unrelated stock.
        // Native read verification only; licensed MCP remains a separate requirement on #95.
        CreateTrackedLine(PurchaseLine, 'OWNED-LOT', '', '', 2);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        PurchaseLine.Validate("Qty. to Receive", 2);
        PurchaseLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        LedgerCount := Ledger.Count();
        EntryCount := Entry.Count();
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.TrackingAvailability.Get", Contract), 'Published Help exists.');
        Contract.Get('examples', Token);
        Token.AsArray().Get(0, Token);
        Example := Token.AsObject();
        Example.Get('request', Token);
        Request := Token.AsObject();
        Request.Get('data', Token);
        Request := Token.AsObject();
        Request.Replace('itemNo', PurchaseLine."No.");
        ExecuteRead(Request, 2, Response);
        AssertSuccess(Response);
        Row := SingleRow(Response, 'availability');
        AssertText(Row, 'lotNo', 'OWNED-LOT');
        AssertDecimal(Row, 'inventory', 2);
        AssertDecimal(Row, 'qtyReserved', 0);
        AssertDecimal(Row, 'availableQuantity', 2);
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'Read does not post.');
        Assert.AreEqual(EntryCount, Entry.Count(), 'Read does not reserve or alter tracking.');
    end;

    /// <summary>Read-only tracking does not restrict the protected native tracking tables for generic requests.</summary>
    [Test]
    procedure Scenario_AC7_ReadTypes_DoNotAddTableWriteRestrictions()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PurchaseLine: Record "Purchase Line";
        Request: JsonObject;
        Response: JsonObject;
        ReservationRestricted: Boolean;
        LedgerRestricted: Boolean;
        SpecificationRestricted: Boolean;
    begin
        // Story #5 AC7: preserve the installed Foundation policy before and after the read.
        CreateTrackedLine(PurchaseLine, 'READ-POLICY', '', '', 2);
        ReservationRestricted := TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Reservation Entry", false);
        LedgerRestricted := TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Ledger Entry", false);
        SpecificationRestricted := TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Tracking Specification", false);
        Request.Add('documentType', 'Purchase.Order');
        Request.Add('documentNo', PurchaseLine."Document No.");
        Request.Add('lineNo', PurchaseLine."Line No.");
        ExecuteRead(Request, 0, Response);
        AssertSuccess(Response);
        Assert.AreEqual(ReservationRestricted, TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Reservation Entry", false), 'Tracking read preserves reservation write policy.');
        Assert.AreEqual(LedgerRestricted, TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Item Ledger Entry", false), 'Tracking read preserves ledger write policy.');
        Assert.AreEqual(SpecificationRestricted, TempArgument.IsTableWriteRestrictedForDataRecords(Database::"Tracking Specification", false), 'Tracking read preserves specification write policy.');
    end;

    local procedure CreateAvailabilityItem(var Item: Record Item; UseExpirationDates: Boolean)
    var
        TrackingCode: Record "Item Tracking Code";
    begin
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode.Validate("Use Expiration Dates", UseExpirationDates);
        TrackingCode.Modify(true);
        LibraryInventory.CreateItem(Item);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
    end;

    local procedure AddTemporaryStock(var TempLedger: Record "Item Ledger Entry" temporary; ItemNo: Code[20]; EntryNo: Integer; ExpirationDate: Date)
    begin
        Assert.IsTrue(TempLedger.IsTemporary(), 'Defensive inconsistent-date inputs must stay in memory.');
        TempLedger.Init();
        TempLedger."Entry No." := EntryNo;
        TempLedger."Item No." := ItemNo;
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
        SourceSpecification: Record "Tracking Specification";
        TempSpecification: Record "Tracking Specification" temporary;
        PurchaseReserve: Codeunit "Purch. Line-Reserve";
        TrackingLines: Page "Item Tracking Lines";
    begin
        // Native setup for this read test; no Inventory tracking-write message is invoked.
        PurchaseReserve.InitFromPurchLine(SourceSpecification, PurchaseLine);
        TempSpecification := SourceSpecification;
        TempSpecification."Entry No." := 1;
        TempSpecification."Lot No." := CopyStr(Lot, 1, MaxStrLen(TempSpecification."Lot No."));
        TempSpecification."Serial No." := CopyStr(Serial, 1, MaxStrLen(TempSpecification."Serial No."));
        TempSpecification."Package No." := CopyStr(Package, 1, MaxStrLen(TempSpecification."Package No."));
        TempSpecification."Quantity (Base)" := Quantity;
        TempSpecification."Expiration Date" := ExpirationDate;
        TempSpecification.Insert();
        TrackingLines.SetBlockCommit(true);
        TrackingLines.RegisterItemTrackingLines(SourceSpecification, WorkDate(), TempSpecification);
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
    local procedure ReserveOwnedSupply(SalesLine: Record "Sales Line"; Ledger: Record "Item Ledger Entry"; Quantity: Decimal)
    var
        Specification: Record "Tracking Specification";
        TempReservation: Record "Reservation Entry" temporary;
        SalesReserve: Codeunit "Sales Line-Reserve";
    begin
        // Only self-created posted supply is passed to the native reservation engine.
        Specification.InitTrackingSpecification(Database::"Item Ledger Entry", 0, '', '', 0, Ledger."Entry No.", Ledger."Variant Code", Ledger."Location Code", Ledger."Qty. per Unit of Measure");
        Specification."Item No." := Ledger."Item No.";
        Specification.Description := Ledger.Description;
        Specification."Quantity (Base)" := Quantity;
        Specification."Lot No." := Ledger."Lot No.";
        Specification."Serial No." := Ledger."Serial No.";
        Specification."Package No." := Ledger."Package No.";
        Specification."Expiration Date" := Ledger."Expiration Date";
        TempReservation."Lot No." := Ledger."Lot No.";
        TempReservation."Serial No." := Ledger."Serial No.";
        TempReservation."Package No." := Ledger."Package No.";
        SalesReserve.CreateReservationSetFrom(Specification);
        SalesReserve.CreateReservation(SalesLine, SalesLine.Description, Ledger."Posting Date", Quantity, Quantity, TempReservation);
    end;

    /// <summary>Purchase adapter preserves every native InitFrom field including non-default units.</summary>
    [Test]
    procedure Scenario_AC1_PurchaseAdapter_MatchesFullNativeRecord()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Expected: Record "Tracking Specification";
        PurchaseReserve: Codeunit "Purch. Line-Reserve";
    begin
        // Story #5 AC1 | Time: WorkDate fixture only | Risk: native adapter field coverage.
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 7);
        LibraryInventory.CreateItemUnitOfMeasureCode(ItemUnit, PurchaseLine."No.", 3);
        PurchaseLine.Validate("Unit of Measure Code", ItemUnit.Code);
        PurchaseLine.Modify(true);
        PurchaseLine.GetBySystemId(PurchaseLine.SystemId);
        PurchaseReserve.InitFromPurchLine(Expected, PurchaseLine);
        AssertNativeAdapter('PurchaseLine', PurchaseLine.SystemId, "Transfer Direction"::Outbound, Expected);
    end;

    /// <summary>Sales adapter preserves every native InitFrom field including non-default units.</summary>
    [Test]
    procedure Scenario_AC1_SalesAdapter_MatchesFullNativeRecord()
    var
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        Expected: Record "Tracking Specification";
        LibrarySales: Codeunit "Library - Sales";
        SalesReserve: Codeunit "Sales Line-Reserve";
    begin
        // Story #5 AC1 | Time: WorkDate fixture only | Risk: native adapter field coverage.
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemUnitOfMeasureCode(ItemUnit, Item."No.", 3);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(Line, Header, Line.Type::Item, Item."No.", 7);
        Line.Validate("Unit of Measure Code", ItemUnit.Code);
        Line.Modify(true);
        Line.GetBySystemId(Line.SystemId);
        SalesReserve.InitFromSalesLine(Expected, Line);
        AssertNativeAdapter('SalesLine', Line.SystemId, "Transfer Direction"::Outbound, Expected);
    end;

    /// <summary>Outbound transfer adapter matches the full native record at the source location.</summary>
    [Test]
    procedure Scenario_AC1_TransferOutbound_MatchesFullNativeRecord()
    begin
        // Story #5 AC1 | Time: WorkDate fixture only | Risk: transfer direction.
        AssertTransferAdapter("Transfer Direction"::Outbound);
    end;

    /// <summary>Inbound transfer adapter matches the full native record at the destination location.</summary>
    [Test]
    procedure Scenario_AC1_TransferInbound_MatchesFullNativeRecord()
    begin
        // Story #5 AC1 | Time: WorkDate fixture only | Risk: transfer direction.
        AssertTransferAdapter("Transfer Direction"::Inbound);
    end;

    /// <summary>Outbound transfer reads project tracking created by the native page, without writes.</summary>
    [Test]
    procedure Scenario_AC1_TransferOutbound_ReadsNativeTracking()
    begin
        AssertTransferTrackingRead(false);
    end;

    /// <summary>Inbound transfer reads preserve the native tracking carried through shipment.</summary>
    [Test]
    procedure Scenario_AC1_TransferInbound_ReadsShippedTracking()
    begin
        AssertTransferTrackingRead(true);
    end;

    local procedure AssertTransferTrackingRead(Inbound: Boolean)
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Header: Record "Transfer Header";
        Line: Record "Transfer Line";
        SourceSpecification: Record "Tracking Specification";
        TempSpecification: Record "Tracking Specification" temporary;
        Entry: Record "Reservation Entry";
        Ledger: Record "Item Ledger Entry";
        Helper: Codeunit "Transfer Order Test Helper";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        TransferReserve: Codeunit "Transfer Line-Reserve";
        TrackingLines: Page "Item Tracking Lines";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        AvailabilityDate: Date;
        BeforeEntries: Integer;
        BeforeLedgers: Integer;
    begin
        // [GIVEN] Self-created tracked supply at an owned source location and a native transfer line.
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);
        LibraryInventory.CreateItemTrackingCode(TrackingCode);
        TrackingCode."Lot Specific Tracking" := true;
        TrackingCode.Modify(true);
        Item.Validate("Item Tracking Code", TrackingCode.Code);
        Item.Modify(true);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        PurchaseHeader.Validate("Location Code", FromLocation.Code);
        PurchaseHeader.Modify(true);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        AssignTracking(PurchaseLine, 'READ-TRANSFER', '', '', 2);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        LibraryWarehouse.CreateTransferLine(Header, Line, Item."No.", 2);
        TransferReserve.InitFromTransLine(SourceSpecification, Line, AvailabilityDate, "Transfer Direction"::Outbound);
        TempSpecification := SourceSpecification;
        TempSpecification."Entry No." := 1;
        TempSpecification."Lot No." := 'READ-TRANSFER';
        TempSpecification."Quantity (Base)" := 2;
        TempSpecification.Insert();
        TrackingLines.SetBlockCommit(true);
        TrackingLines.RegisterItemTrackingLines(SourceSpecification, AvailabilityDate, TempSpecification);
        if Inbound then
            LibraryWarehouse.PostTransferOrder(Header, true, false);
        BeforeEntries := Entry.Count();
        BeforeLedgers := Ledger.Count();
        Request.Add('documentType', 'Transfer.Order');
        Request.Add('documentNo', Header."No.");
        Request.Add('lineNo', Line."Line No.");
        if Inbound then
            Request.Add('transferDirection', 'Inbound');

        // [WHEN] The eligible read implementation resolves the real transfer source.
        ExecuteRead(Request, 0, Response);

        // [THEN] Its native lot and direction remain visible, with no persistent read effects.
        AssertSuccess(Response);
        Row := SingleRow(Response, 'trackingLines');
        AssertText(Row, 'sourceType', 'TransferLine');
        AssertText(Row, 'documentNo', Header."No.");
        AssertText(Row, 'lotNo', 'READ-TRANSFER');
        if Inbound then begin
            AssertText(Row, 'locationCode', ToLocation.Code);
            AssertDecimal(Row, 'quantityBase', 2);
        end else begin
            AssertText(Row, 'locationCode', FromLocation.Code);
            AssertDecimal(Row, 'quantityBase', -2);
        end;
        Assert.AreEqual(BeforeEntries, Entry.Count(), 'Transfer read cannot write tracking entries.');
        Assert.AreEqual(BeforeLedgers, Ledger.Count(), 'Transfer read cannot post inventory.');
    end;

    local procedure AssertTransferAdapter(Direction: Enum "Transfer Direction")
    var
        Item: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Header: Record "Transfer Header";
        Line: Record "Transfer Line";
        Expected: Record "Tracking Specification";
        Helper: Codeunit "Transfer Order Test Helper";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        TransferReserve: Codeunit "Transfer Line-Reserve";
        AvailabilityDate: Date;
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 0);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        LibraryWarehouse.CreateTransferLine(Header, Line, Item."No.", 7);
        Line.GetBySystemId(Line.SystemId);
        TransferReserve.InitFromTransLine(Expected, Line, AvailabilityDate, Direction);
        AssertNativeAdapter('TransferLine', Line.SystemId, Direction, Expected);
    end;

    local procedure AssertNativeAdapter(TypeName: Text; Id: Guid; ExpectedDirection: Enum "Transfer Direction"; var Expected: Record "Tracking Specification")
    var
        Actual: Record "Tracking Specification";
        TempArgument: Record "Message Argument ori" temporary;
        Resolver: Codeunit "Inventory Tracking Read ori";
        SourceRef: RecordRef;
        ExpectedRef: RecordRef;
        ActualRef: RecordRef;
        ExpectedField: FieldRef;
        ActualField: FieldRef;
        Direction: Enum "Transfer Direction";
        Source: JsonObject;
        Request: JsonObject;
        Index: Integer;
    begin
        Source.Add('type', TypeName);
        Source.Add('systemId', Format(Id, 0, 4));
        if ExpectedDirection = ExpectedDirection::Inbound then
            Source.Add('transferDirection', 'Inbound');
        Request.Add('source', Source);
        InitArgument(TempArgument, Request);
        Assert.IsTrue(Resolver.ResolveDocument(TempArgument, Request, false, SourceRef, Actual, Direction), 'Owned source resolves.');
        Assert.AreEqual(ExpectedDirection, Direction, 'Native direction is preserved.');
        ExpectedRef.GetTable(Expected);
        ActualRef.GetTable(Actual);
        for Index := 1 to ExpectedRef.FieldCount() do begin
            ExpectedField := ExpectedRef.FieldIndex(Index);
            ActualField := ActualRef.Field(ExpectedField.Number());
            Assert.AreEqual(ExpectedField.Value, ActualField.Value, TypeName + ': native field ' + ExpectedField.Name());
        end;
    end;
}
