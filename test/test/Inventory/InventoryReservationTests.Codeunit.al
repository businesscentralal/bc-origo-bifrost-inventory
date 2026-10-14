namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Proves explicit manual pairing, availability refusals and source-scoped cancellation.</summary>
codeunit 96926 "Inventory Reservation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryPurchase: Codeunit "Library - Purchase";

    /// <summary>A reservation pairs only the selected sales line and the selected posted supply.</summary>
    [Test]
    procedure ManualReservationPairsSelectedSources()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        OppositeEntry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);

        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 2), false, Response);

        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.AreEqual(1, ReservationEntry.Count(), 'Exactly one demand reservation.');
        ReservationEntry.FindFirst();
        Assert.AreEqual(-2, ReservationEntry."Quantity (Base)", 'Demand sign is native.');
        OppositeEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive);
        Assert.AreEqual(Database::"Item Ledger Entry", OppositeEntry."Source Type", 'Supply is posted inventory.');
        Assert.AreEqual(ItemLedgerEntry."Entry No.", OppositeEntry."Source Ref. No.", 'Supply selection is explicit.');
        Assert.AreEqual(2, OppositeEntry."Quantity (Base)", 'Supply sign is native.');
    end;

    /// <summary>Over-reservation is refused without creating either side of a pair.</summary>
    [Test]
    procedure ExcessQuantityLeavesSourcesUnreserved()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);

        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 11), false, Response);

        AssertStatus(Response, 'Error');
        ReservationEntry.SetRange("Item No.", SalesLine."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'No partial pair after refused quantity.');
    end;

    /// <summary>Cancellation removes the selected pair and is idempotent by source.</summary>
    [Test]
    procedure CancelSourceRemovesPairAndRepeatedCancelReturnsZero()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 2), false, Response);
        AssertStatus(Response, 'Success');
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));

        ExecuteReservation(Request, true, Response);

        AssertStatus(Response, 'Success');
        Response.Get('itemNo', Token);
        Assert.AreEqual(SalesLine."No.", Token.AsValue().AsText(), 'Cancellation identifies the actual item.');
        Response.Get('quantityUnreserved', Token);
        Assert.AreEqual(2, Token.AsValue().AsDecimal(), 'Cancellation returns the actual source quantity released.');
        ReservationEntry.SetRange("Item No.", SalesLine."No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Both paired reservation rows are removed.');
        ExecuteReservation(Request, true, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entriesCancelled', Token);
        Assert.AreEqual(0, Token.AsValue().AsInteger(), 'Repeated source cancellation is a no-op.');
    end;

    /// <summary>A different line cannot cancel an existing reservation by entry number.</summary>
    [Test]
    procedure CancelEntryRejectsForeignSource()
    var
        SalesLine: Record "Sales Line";
        OtherLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        OtherEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        CreateSources(OtherLine, OtherEntry);
        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.FindFirst();
        Request.Add('source', SourceObject('SalesLine', OtherLine.SystemId));
        Request.Add('entryNo', ReservationEntry."Entry No.");

        ExecuteReservation(Request, true, Response);

        AssertStatus(Response, 'Error');
        Assert.AreEqual(1, ReservationEntry.Count(), 'Other source reservation remains unchanged.');
    end;

    /// <summary>Entry-only cancellation resolves the native demand source and removes its pair.</summary>
    [Test]
    procedure CancelByEntryResolvesSource()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 2), false, Response);
        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.FindFirst();
        Request.Add('entryNo', ReservationEntry."Entry No.");

        ExecuteReservation(Request, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Selected demand reservation is removed.');
        ExecuteReservation(Request, true, Response);
        AssertStatus(Response, 'Error');
    end;

    /// <summary>The purchase Reserve source pairs with the explicitly selected sales line.</summary>
    [Test]
    procedure PurchaseSourcePairsWithSalesDemand()
    var
        SalesLine: Record "Sales Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        OppositeEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, SalesLine."No.", 10);
        Request.Add('source', SourceObject('PurchaseLine', PurchaseLine.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.FindFirst();
        OppositeEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive);
        Assert.AreEqual(Database::"Purchase Line", OppositeEntry."Source Type", 'Selected purchase source is paired.');
        Assert.AreEqual(PurchaseLine."Document No.", OppositeEntry."Source ID", 'No other purchase source is selected.');
    end;

    /// <summary>Prior reservations reduce both sources' remaining reservable quantity.</summary>
    [Test]
    procedure ExistingReservationPreventsOverReservation()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 6), false, Response);
        AssertStatus(Response, 'Success');

        ExecuteReservation(CreateRequest(SalesLine, ItemLedgerEntry, 5), false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.CalcSums("Quantity (Base)");
        Assert.AreEqual(-6, ReservationEntry."Quantity (Base)", 'Existing reservation remains unchanged.');
    end;

    /// <summary>Legacy document keys and a named ledger number reserve exactly the selected supply.</summary>
    [Test]
    procedure LegacyDocumentKeysReserveNamedInventory()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        OppositeEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        Request.Add('documentType', 'Order');
        Request.Add('documentNo', SalesLine."Document No.");
        Request.Add('lineNo', SalesLine."Line No.");
        Request.Add('itemLedgerEntryNo', ItemLedgerEntry."Entry No.");
        Request.Add('quantity', 2);

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.FindFirst();
        Assert.AreEqual(-2, ReservationEntry."Quantity (Base)", 'Legacy keys resolve the source.');
        OppositeEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive);
        Assert.AreEqual(ItemLedgerEntry."Entry No.", OppositeEntry."Source Ref. No.", 'Only the named supply is reserved.');
        Request.Remove('itemLedgerEntryNo');
        Request.Remove('quantity');
        ExecuteReservation(Request, true, Response);
        AssertStatus(Response, 'Success');
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Legacy source cancellation removes the native pair.');
    end;

    /// <summary>A requested lot cannot silently reserve a differently tracked supply entry.</summary>
    [Test]
    procedure RequestedLotMismatchRefusesWithoutReservation()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        Request := CreateRequest(SalesLine, ItemLedgerEntry, 2);
        Request.Add('lotNo', 'NOT-ON-SUPPLY');

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Tracking mismatch leaves both sources unchanged.');
    end;

    /// <summary>Conflicting supply selectors are refused before a native reservation is created.</summary>
    [Test]
    procedure ConflictingSupplySelectorsRefuseWithoutReservation()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        Request := CreateRequest(SalesLine, ItemLedgerEntry, 2);
        Request.Add('itemLedgerEntryNo', ItemLedgerEntry."Entry No.");

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Ambiguous supply never silently chooses one selector.');
    end;

    /// <summary>Omitting explicit supply reserves matching posted inventory through the same native pair path.</summary>
    [Test]
    procedure GeneralInventoryCreatesNativePair()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        OppositeEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 4);

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        ReservationEntry.FindFirst();
        Assert.AreEqual(-4, ReservationEntry."Quantity (Base)", 'Requested inventory quantity.');
        OppositeEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive);
        Assert.AreEqual(ItemLedgerEntry."Entry No.", OppositeEntry."Source Ref. No.", 'Native pair uses posted stock.');
    end;

    /// <summary>General inventory is preflighted across all required entries before any pair is written.</summary>
    [Test]
    procedure InsufficientGeneralInventoryLeavesNoPartialReservation()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        SalesLine.Validate(Quantity, 20);
        SalesLine.Modify(true);
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 11);

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Available first ten units are not partially reserved.');
    end;

    /// <summary>A reservation spanning two posted entries uses deterministic native pairs and exact base totals.</summary>
    [Test]
    procedure GeneralInventorySplitsAcrossPostedEntries()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, ItemLedgerEntry);
        SalesLine.Validate(Quantity, 20);
        SalesLine.Modify(true);
        LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJournalBatch, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, ItemJournalLine."Entry Type"::"Positive Adjmt.", SalesLine."No.", 5);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 12);

        ExecuteReservation(Request, false, Response);

        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.AreEqual(2, ReservationEntry.Count(), 'Two source reservations pair with the two receipt entries.');
        ReservationEntry.CalcSums("Quantity (Base)");
        Assert.AreEqual(-12, ReservationEntry."Quantity (Base)", 'Exact requested base quantity is reserved.');
    end;

    /// <summary>Assembly output reserves against a selected sales demand and cancels both native sides.</summary>
    [Test]
    procedure AssemblyOutputPairsAndCancelsSalesDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Assembly Header";
        LibraryAssembly: Codeunit "Library - Assembly";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), SalesLine."No.", '', 10, '');
        Request.Add('source', SourceObject('AssemblyHeader', Header.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Assembly Header", Header."No.", '', 0, true, 2, 0);
    end;

    /// <summary>Assembly components use their line identity when manually reserving posted inventory.</summary>
    [Test]
    procedure AssemblyComponentPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        ParentItem: Record Item;
        Header: Record "Assembly Header";
        Line: Record "Assembly Line";
        LibraryAssembly: Codeunit "Library - Assembly";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryInventory.CreateItem(ParentItem);
        LibraryAssembly.CreateAssemblyHeader(Header, WorkDate(), ParentItem."No.", '', 10, '');
        LibraryAssembly.CreateAssemblyLine(Header, Line, Line.Type::Item, SalesLine."No.", SalesLine."Unit of Measure Code", 10, 1, '');
        Request.Add('source', SourceObject('AssemblyLine', Line.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Assembly Line", Line."Document No.", '', Line."Line No.", false, 2, 0);
    end;

    /// <summary>Item journal reservations preserve both template and batch and cancel through the native adapter.</summary>
    [Test]
    procedure TransferJournalPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::Transfer, SalesLine."No.", 10);
        Request.Add('source', SourceObject('ItemJournalLine', Line.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Item Journal Line", JournalTemplate.Name, Batch.Name, Line."Line No.", false, 2, 0);
    end;

    /// <summary>Manual source quantity is converted to base units before native pairing, without double conversion.</summary>
    [Test]
    procedure NonBaseSalesUnitReservesExactBaseQuantity()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        ItemUnit: Record "Item Unit of Measure";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryInventory.CreateItemUnitOfMeasureCode(ItemUnit, SalesLine."No.", 3);
        SalesLine.Validate("Unit of Measure Code", ItemUnit.Code);
        SalesLine.Validate(Quantity, 3);
        SalesLine.Modify(true);
        Request := CreateRequest(SalesLine, Ledger, 2);

        AssertNativeRoundTrip(Request, Database::"Sales Line", SalesLine."Document No.", '', SalesLine."Line No.", false, 6, 0);
    end;

    /// <summary>Posted inventory can be the selected source, with the native demand adapter creating its pair.</summary>
    [Test]
    procedure PostedInventorySourcePairsAndCancelsDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        Request.Add('source', SourceObject('ItemLedgerEntry', Ledger.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Item Ledger Entry", '', '', Ledger."Entry No.", true, 2, 0);
    end;

    /// <summary>Production output uses the production-line pointer, not a document reference-line substitute.</summary>
    [Test]
    procedure ProductionOutputPairsAndCancelsDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Production Order";
        Line: Record "Prod. Order Line";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryManufacturing.CreateProductionOrder(Header, Header.Status::"Firm Planned", Header."Source Type"::Item, SalesLine."No.", 10);
        LibraryManufacturing.CreateProdOrderLine(Line, Header.Status, Header."No.", SalesLine."No.", '', '', 10);
        Line.Validate("Due Date", WorkDate());
        Line.Modify(true);
        Request.Add('source', SourceObject('ProdOrderLine', Line.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Prod. Order Line", Header."No.", '', 0, true, 2, Line."Line No.");
    end;

    /// <summary>Production component reservations preserve both parent production line and component line.</summary>
    [Test]
    procedure ProductionComponentPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        ParentItem: Record Item;
        Header: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryInventory.CreateItem(ParentItem);
        LibraryManufacturing.CreateProductionOrder(Header, Header.Status::"Firm Planned", Header."Source Type"::Item, ParentItem."No.", 10);
        LibraryManufacturing.CreateProdOrderLine(Line, Header.Status, Header."No.", ParentItem."No.", '', '', 10);
        Line.Validate("Due Date", WorkDate());
        Line.Modify(true);
        LibraryManufacturing.CreateProductionOrderComponent(Component, Header.Status, Header."No.", Line."Line No.");
        Component.Validate("Item No.", SalesLine."No.");
        Component.Validate("Quantity per", 1);
        Component.Validate("Due Date", WorkDate());
        Component.Modify(true);
        Request.Add('source', SourceObject('ProdOrderComponent', Component.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Prod. Order Component", Header."No.", '', Component."Line No.", false, 2, Line."Line No.");
    end;

    /// <summary>A validated service item line reserves inventory and cancels via Service Line-Reserve.</summary>
    [Test]
    procedure ServiceLinePairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Service Header";
        Line: Record "Service Line";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        Header.Init();
        Header."Document Type" := Header."Document Type"::Order;
        Header.Insert(true);
        Header.Validate("Customer No.", SalesLine."Sell-to Customer No.");
        Header.Modify(true);
        Line.Init();
        Line."Document Type" := Header."Document Type";
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line.Insert(true);
        Line.Validate(Type, Line.Type::Item);
        Line.Validate("No.", SalesLine."No.");
        Line.Validate(Quantity, 10);
        Line.Validate("Needed by Date", WorkDate());
        Line.Modify(true);
        Request.Add('source', SourceObject('ServiceLine', Line.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Service Line", Header."No.", '', Line."Line No.", false, 2, 0);
    end;

    /// <summary>Outbound transfer reservation uses the transfer-from location and native outbound direction.</summary>
    [Test]
    procedure TransferOutboundPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Line: Record "Transfer Line";
        Request: JsonObject;
        Source: JsonObject;
    begin
        CreateTransferSources(SalesLine, Ledger, Line);
        Source := SourceObject('TransferLine', Line.SystemId);
        Source.Add('transferDirection', 'Outbound');
        Request.Add('source', Source);
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Transfer Line", Line."Document No.", '', Line."Line No.", false, 2, 0);
    end;

    /// <summary>Inbound transfer supply pairs with demand at the transfer-to location, independently of outbound stock.</summary>
    [Test]
    procedure TransferInboundPairsAndCancelsDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Line: Record "Transfer Line";
        Request: JsonObject;
        Source: JsonObject;
    begin
        CreateTransferSources(SalesLine, Ledger, Line);
        SalesLine.Validate("Location Code", Line."Transfer-to Code");
        SalesLine.Modify(true);
        Source := SourceObject('TransferLine', Line.SystemId);
        Source.Add('transferDirection', 'Inbound');
        Request.Add('source', Source);
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Transfer Line", Line."Document No.", '', Line."Line No.", true, 2, 0);
    end;

    /// <summary>Sales return orders provide native supply and retain their return-order source subtype.</summary>
    [Test]
    procedure SalesReturnPairsAndCancelsSalesDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Sales Header";
        ReturnLine: Record "Sales Line";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::"Return Order", '');
        LibrarySales.CreateSalesLine(ReturnLine, Header, ReturnLine.Type::Item, SalesLine."No.", 10);
        Request.Add('source', SourceObject('SalesLine', ReturnLine.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Sales Line", ReturnLine."Document No.", '', ReturnLine."Line No.", true, 2, 0);
    end;

    /// <summary>Purchase returns reserve posted inventory as native demand and cancel their own pair.</summary>
    [Test]
    procedure PurchaseReturnPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Purchase Header";
        ReturnLine: Record "Purchase Line";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryPurchase.CreatePurchHeader(Header, Header."Document Type"::"Return Order", '');
        LibraryPurchase.CreatePurchaseLine(ReturnLine, Header, ReturnLine.Type::Item, SalesLine."No.", 10);
        Request.Add('source', SourceObject('PurchaseLine', ReturnLine.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        AssertNativeRoundTrip(Request, Database::"Purchase Line", ReturnLine."Document No.", '', ReturnLine."Line No.", false, 2, 0);
    end;

    /// <summary>A real partial shipment limits reservation to the unshipped source and remaining posted stock.</summary>
    [Test]
    procedure PartialShipmentReservesOnlyRemainingQuantity()
    var
        SalesLine: Record "Sales Line";
        Header: Record "Sales Header";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        SalesLine.Validate("Qty. to Ship", 4);
        SalesLine.Modify(true);
        Header.Get(SalesLine."Document Type", SalesLine."Document No.");
        LibrarySales.PostSalesDocument(Header, true, false);
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Ledger.Get(Ledger."Entry No.");
        Assert.AreEqual(6, SalesLine."Outstanding Qty. (Base)", 'The real source is partially posted.');
        Assert.AreEqual(6, Ledger."Remaining Quantity", 'The posted inventory reflects the real shipment.');

        ExecuteReservation(CreateRequest(SalesLine, Ledger, 7), false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, Entry);
        Assert.IsTrue(Entry.IsEmpty(), 'Refusal leaves no partial reservation.');
        AssertNativeRoundTrip(CreateRequest(SalesLine, Ledger, 6), Database::"Sales Line", SalesLine."Document No.", '', SalesLine."Line No.", false, 6, 0);
    end;

    /// <summary>A fully shipped source refuses new reservations before looking at closed supply.</summary>
    [Test]
    procedure FullyShippedSourceRefusesCreate()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Entry: Record "Reservation Entry";
        Response: JsonObject;
    begin
        CreateFullyShippedSource(SalesLine, Ledger);

        ExecuteReservation(CreateRequest(SalesLine, Ledger, 1), false, Response);

        AssertStatus(Response, 'Error');
        FilterSalesReservations(SalesLine, Entry);
        Assert.IsTrue(Entry.IsEmpty(), 'Closed source creates no reservations.');
    end;

    /// <summary>Closed-source cancellation is a structured refusal, distinct from an open unreserved source no-op.</summary>
    [Test]
    procedure FullyShippedSourceRefusesCancel()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateFullyShippedSource(SalesLine, Ledger);
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));

        ExecuteReservation(Request, true, Response);

        AssertStatus(Response, 'Error');
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Assert.AreEqual(10, SalesLine."Quantity Shipped", 'Refusal preserves the real posted source.');
    end;

    /// <summary>An open native project planning demand reserves and cancels exact posted inventory through its contract-entry pointer.</summary>
    [Test]
    procedure JobPlanningLinePairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Job: Record Job;
        JobTask: Record "Job Task";
        PlanningLine: Record "Job Planning Line";
        LibraryJob: Codeunit "Library - Job";
        Request: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryJob.CreateJob(Job);
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryJob.CreateJobPlanningLine(JobTask, PlanningLine."Line Type"::Budget, PlanningLine.Type::Item, SalesLine."No.", 10, PlanningLine);
        Request.Add('source', SourceObject('JobPlanningLine', PlanningLine.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);
        AssertNativeRoundTrip(Request, Database::"Job Planning Line", Job."No.", '', PlanningLine."Job Contract Entry No.", false, 2, 0);
    end;

    /// <summary>A project journal tracking adapter without native CreateReservation support cannot report a successful reservation.</summary>
    [Test]
    procedure JobJournalNativeNoOpRefusesWithoutReservations()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Job: Record Job;
        JobTask: Record "Job Task";
        JournalLine: Record "Job Journal Line";
        Entry: Record "Reservation Entry";
        LibraryJob: Codeunit "Library - Job";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryJob.CreateJob(Job);
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryJob.CreateJobJournalLine(JournalLine."Line Type"::Budget, JobTask, JournalLine);
        JournalLine.Validate(Type, JournalLine.Type::Item);
        JournalLine.Validate("No.", SalesLine."No.");
        JournalLine.Validate(Quantity, 10);
        JournalLine.Modify(true);
        Request.Add('source', SourceObject('JobJournalLine', JournalLine.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);
        Commit();
        asserterror ExecuteReservation(Request, false, Response);
        Assert.ExpectedError('did not reserve the requested base quantity');
        Request.Remove('itemLedgerEntryNo');
        asserterror ExecuteReservation(Request, false, Response);
        Assert.ExpectedError('did not reserve the requested base quantity');
        Entry.SetRange("Item No.", SalesLine."No.");
        Assert.IsTrue(Entry.IsEmpty(), 'A native no-op leaves no partial reservation or tracking rows.');
        JournalLine.Get(JournalLine."Journal Template Name", JournalLine."Journal Batch Name", JournalLine."Line No.");
        Assert.AreEqual(10, JournalLine.Quantity, 'Native source quantity is unchanged.');
    end;

    /// <summary>Native requisition supply requires order-to-order binding and refuses ordinary manual reservations.</summary>
    [Test]
    procedure Scenario_AC04_RequisitionLineRequiresNativeBinding()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        RequisitionLine: Record "Requisition Line";
        Request: JsonObject;
    begin
        // Story #7, AC04/AC05/AC08 | Time: WorkDate for native due dates | Risk: None.
        // [GIVEN] Owned requisition supply and a matching sales demand.
        CreateSources(SalesLine, Ledger);
        CreateOwnedRequisitionLine(RequisitionLine, SalesLine."No.");
        Request.Add('source', SourceObject('RequisitionLine', RequisitionLine.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        // [WHEN] Attempt an ordinary manual reservation without native order-to-order binding.
        // [THEN] Req. Line-Reserve rejects it before a partial pair can survive.
        AssertNativeBindingRefusal(Request, SalesLine."No.", Ledger);
    end;

    /// <summary>Native planning components require order-to-order binding and refuse ordinary manual reservations.</summary>
    [Test]
    procedure Scenario_AC05_PlanningComponentRequiresNativeBinding()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        RequisitionLine: Record "Requisition Line";
        Component: Record "Planning Component";
        OtherComponent: Record "Planning Component";
        LibraryPlanning: Codeunit "Library - Planning";
        Request: JsonObject;
    begin
        // Story #7, AC04/AC05/AC08 | Time: WorkDate for native due dates | Risk: None.
        // [GIVEN] An owned planning component with ten units of demand and posted supply.
        CreateSources(SalesLine, Ledger);
        CreateOwnedRequisitionLine(RequisitionLine, SalesLine."No.");
        LibraryPlanning.CreatePlanningComponent(OtherComponent, RequisitionLine);
        LibraryPlanning.CreatePlanningComponent(Component, RequisitionLine);
        Component.Validate("Item No.", SalesLine."No.");
        Component.Validate("Expected Quantity", 10);
        Component.Validate("Due Date", WorkDate());
        Component.Modify(true);
        Component.Get(Component."Worksheet Template Name", Component."Worksheet Batch Name", Component."Worksheet Line No.", Component."Line No.");
        Request.Add('source', SourceObject('PlanningComponent', Component.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        // [WHEN] Attempt an ordinary manual reservation without native order-to-order binding.
        // [THEN] Plng. Component-Reserve rejects it without changing the posted supply.
        AssertNativeBindingRefusal(Request, SalesLine."No.", Ledger);
    end;

    /// <summary>An inventory shipment reserves selected posted inventory through the native document adapter.</summary>
    [Test]
    procedure Scenario_AC05_AC08_InventoryShipmentPairsAndCancelsInventory()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Invt. Document Header";
        Line: Record "Invt. Document Line";
        Location: Record Location;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Request: JsonObject;
    begin
        // Story #7, AC04/AC05/AC08 | Time: WorkDate for document and posting dates | Risk: None.
        // [GIVEN] An owned inventory shipment and matching posted stock.
        EnableInventoryDocumentReservation();
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        CreateSourcesAtLocation(SalesLine, Ledger, Location.Code);
        LibraryInventory.CreateInvtDocument(Header, Header."Document Type"::Shipment, Location.Code);
        Header.Validate("Document Date", WorkDate());
        Header.Modify(true);
        LibraryInventory.CreateInvtDocumentLine(Header, Line, SalesLine."No.", 0, 10);
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(10, Line.Quantity, 'Owned inventory document has outstanding quantity.');
        Assert.AreEqual(10, Line."Quantity (Base)", 'Owned inventory document has native base quantity.');
        Request.Add('source', SourceObject('InventoryDocumentLine', Line.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        // [WHEN] Reserve inventory and cancel using both supported selectors.
        // [THEN] The native shipment source and opposite inventory row are removed together.
        AssertNativeRoundTrip(Request, Database::"Invt. Document Line", Header."No.", '', Line."Line No.", false, 2, 0);
    end;

    /// <summary>An inventory receipt provides native supply without being confused with a shipment.</summary>
    [Test]
    procedure Scenario_AC04_AC08_InventoryReceiptPairsAndCancelsDemand()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        Header: Record "Invt. Document Header";
        Line: Record "Invt. Document Line";
        Location: Record Location;
        LibraryWarehouse: Codeunit "Library - Warehouse";
        Request: JsonObject;
    begin
        // Story #7, AC04/AC05/AC08 | Time: WorkDate for document and posting dates | Risk: None.
        // [GIVEN] An owned inventory receipt and matching sales demand.
        EnableInventoryDocumentReservation();
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        CreateSourcesAtLocation(SalesLine, Ledger, Location.Code);
        LibraryInventory.CreateInvtDocument(Header, Header."Document Type"::Receipt, Location.Code);
        Header.Validate("Document Date", WorkDate());
        Header.Modify(true);
        LibraryInventory.CreateInvtDocumentLine(Header, Line, SalesLine."No.", 0, 10);
        Line.Get(Line."Document Type", Line."Document No.", Line."Line No.");
        Assert.AreEqual(10, Line.Quantity, 'Owned inventory document has outstanding quantity.');
        Assert.AreEqual(10, Line."Quantity (Base)", 'Owned inventory document has native base quantity.');
        Request.Add('source', SourceObject('InventoryDocumentLine', Line.SystemId));
        Request.Add('supply', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('quantity', 2);

        // [WHEN] Reserve the demand and cancel using both supported selectors.
        // [THEN] The receipt creates a positive native source and cancellation removes both sides.
        AssertNativeRoundTrip(Request, Database::"Invt. Document Line", Header."No.", '', Line."Line No.", true, 2, 0);
    end;

    local procedure CreateOwnedRequisitionLine(var RequisitionLine: Record "Requisition Line"; ItemNo: Code[20])
    var
        WorksheetTemplate: Record "Req. Wksh. Template";
        WorksheetName: Record "Requisition Wksh. Name";
        LibraryPlanning: Codeunit "Library - Planning";
    begin
        WorksheetTemplate.Init();
        WorksheetTemplate.Name := CopyStr('BIFT' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(WorksheetTemplate.Name));
        WorksheetTemplate.Insert(true);
        WorksheetTemplate.Validate(Type, WorksheetTemplate.Type::Planning);
        WorksheetTemplate.Modify(true);
        LibraryPlanning.CreateRequisitionWkshName(WorksheetName, WorksheetTemplate.Name);
        LibraryPlanning.CreateRequisitionLine(RequisitionLine, WorksheetTemplate.Name, WorksheetName.Name);
        RequisitionLine.Validate(Type, RequisitionLine.Type::Item);
        RequisitionLine.Validate("No.", ItemNo);
        RequisitionLine.Validate(Quantity, 10);
        RequisitionLine.Validate("Due Date", WorkDate());
        RequisitionLine.Modify(true);
        RequisitionLine.Get(RequisitionLine."Worksheet Template Name", RequisitionLine."Journal Batch Name", RequisitionLine."Line No.");
    end;

    local procedure CreateFullyShippedSource(var SalesLine: Record "Sales Line"; var Ledger: Record "Item Ledger Entry")
    var
        Header: Record "Sales Header";
    begin
        CreateSources(SalesLine, Ledger);
        Header.Get(SalesLine."Document Type", SalesLine."Document No.");
        LibrarySales.PostSalesDocument(Header, true, false);
        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        Assert.AreEqual(0, SalesLine."Outstanding Qty. (Base)", 'Fixture is fully shipped, not merely zeroed by a test.');
    end;

    local procedure CreateTransferSources(var SalesLine: Record "Sales Line"; var Ledger: Record "Item Ledger Entry"; var TransferLine: Record "Transfer Line")
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        TransitLocation: Record Location;
        Header: Record "Transfer Header";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        JournalLine: Record "Item Journal Line";
        LibraryWarehouse: Codeunit "Library - Warehouse";
    begin
        CreateSources(SalesLine, Ledger);
        LibraryWarehouse.CreateTransferLocations(FromLocation, ToLocation, TransitLocation);
        LibraryInventory.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, TransitLocation.Code);
        LibraryInventory.CreateTransferLine(Header, TransferLine, SalesLine."No.", 10);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(JournalLine, JournalTemplate.Name, Batch.Name, JournalLine."Entry Type"::"Positive Adjmt.", SalesLine."No.", 10);
        JournalLine.Validate("Location Code", FromLocation.Code);
        JournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
        Ledger.SetRange("Location Code", FromLocation.Code);
        Ledger.FindLast();
    end;

    /// <summary>W1 rejects ordinary adjustment journals as reservation sources without creating a partial pair.</summary>
    [Test]
    procedure AdjustmentJournalNativeRefusalLeavesNoReservations()
    var
        SalesLine: Record "Sales Line";
        Ledger: Record "Item Ledger Entry";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreateSources(SalesLine, Ledger);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Negative Adjmt.", SalesLine."No.", 10);
        Request.Add('source', SourceObject('ItemJournalLine', Line.SystemId));
        Request.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Request.Add('quantity', 2);

        asserterror ExecuteReservation(Request, false, Response);

        Assert.ExpectedError('not a true demand or supply');
        Entry.SetRange("Item No.", SalesLine."No.");
        Entry.SetRange("Reservation Status", Entry."Reservation Status"::Reservation);
        Assert.IsTrue(Entry.IsEmpty(), 'Native unsupported-source refusal cannot leave either reservation side.');
    end;

    local procedure AssertNativeRoundTrip(Request: JsonObject; TableNo: Integer; SourceId: Code[20]; BatchName: Code[10]; RefNo: Integer; Positive: Boolean; BaseQuantity: Decimal; ProdLineNo: Integer)
    var
        Entry: Record "Reservation Entry";
        Opposite: Record "Reservation Entry";
        Response: JsonObject;
        CancelRequest: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        SourceQuantity: Decimal;
    begin
        Request.Get('quantity', Token);
        SourceQuantity := Token.AsValue().AsDecimal();
        ExecuteReservation(Request, false, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        EntryNo := Token.AsValue().AsInteger();
        Entry.Get(EntryNo, Positive);
        Assert.AreEqual(TableNo, Entry."Source Type", 'Native pair has the requested source table.');
        Assert.AreEqual(SourceId, Entry."Source ID", 'Native pair has the requested source document/template.');
        Assert.AreEqual(BatchName, Entry."Source Batch Name", 'Native pair has the requested batch.');
        Assert.AreEqual(RefNo, Entry."Source Ref. No.", 'Native pair has the requested source line.');
        Assert.AreEqual(ProdLineNo, Entry."Source Prod. Order Line", 'Production line identity is preserved independently from reference line.');
        Assert.AreEqual(BaseQuantity, Abs(Entry."Quantity (Base)"), 'Source has exact base quantity.');
        Opposite.Get(EntryNo, not Positive);
        Assert.AreEqual(-Entry."Quantity (Base)", Opposite."Quantity (Base)", 'Native pair balances exactly.');
        Request.Get('source', Token);
        CancelRequest.Add('source', Token);
        CancelRequest.Add('entryNo', EntryNo);

        ExecuteReservation(CancelRequest, true, Response);

        AssertStatus(Response, 'Success');
        Response.Get('quantityUnreserved', Token);
        Assert.AreEqual(SourceQuantity, Token.AsValue().AsDecimal(), 'Cancelled quantity uses the selected source UOM.');
        Response.Get('quantityBaseUnreserved', Token);
        Assert.AreEqual(BaseQuantity, Token.AsValue().AsDecimal(), 'Cancelled base quantity is exact.');
        Assert.IsFalse(Entry.Get(EntryNo, Positive), 'Selected source reservation was cancelled.');
        Assert.IsFalse(Opposite.Get(EntryNo, not Positive), 'The opposite native reservation was cancelled too.');
        // Recreate the same native pair, then resolve cancellation from its entry number alone.
        ExecuteReservation(Request, false, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        EntryNo := Token.AsValue().AsInteger();
        Clear(CancelRequest);
        CancelRequest.Add('entryNo', EntryNo);

        ExecuteReservation(CancelRequest, true, Response);

        AssertStatus(Response, 'Success');
        Assert.IsFalse(Entry.Get(EntryNo, Positive), 'Entry-only cancellation removes the selected source side.');
        Assert.IsFalse(Opposite.Get(EntryNo, not Positive), 'Entry-only cancellation removes the opposite side too.');
        // The source-only mode must work independently of the optional entry selector.
        ExecuteReservation(Request, false, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entryNo', Token);
        EntryNo := Token.AsValue().AsInteger();
        Clear(CancelRequest);
        Request.Get('source', Token);
        CancelRequest.Add('source', Token);

        ExecuteReservation(CancelRequest, true, Response);

        AssertStatus(Response, 'Success');
        Response.Get('quantityUnreserved', Token);
        Assert.AreEqual(SourceQuantity, Token.AsValue().AsDecimal(), 'Source-only cancellation keeps source UOM.');
        Response.Get('quantityBaseUnreserved', Token);
        Assert.AreEqual(BaseQuantity, Token.AsValue().AsDecimal(), 'Source-only cancellation keeps base quantity.');
        Assert.IsFalse(Entry.Get(EntryNo, Positive), 'Source-only cancellation removes the selected side.');
        Assert.IsFalse(Opposite.Get(EntryNo, not Positive), 'Source-only cancellation removes the paired side.');
        ExecuteReservation(CancelRequest, true, Response);
        AssertStatus(Response, 'Success');
        Response.Get('entriesCancelled', Token);
        Assert.AreEqual(0, Token.AsValue().AsInteger(), 'Repeated source-only cancellation is an empty success.');
    end;

    /// <summary>Published Help examples form, read and cancel a native pair using only owned fixtures.</summary>
    [Test]
    procedure Scenario_AC1_PublicExamples_CreateReadCancelOwnedPair()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        OppositeEntry: Record "Reservation Entry";
        TempArgument: Record "Message Argument ori" temporary;
        TrackingRead: Codeunit "Inventory Tracking Read ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        PairNo: Integer;
        LedgerCount: Integer;
    begin
        // Issue #7 | Time: native fixture WorkDate | Risk: source/quantity examples omit real pairing requirements.
        // Native layer only; no licensed dispatch or full MCP acceptance is claimed.
        CreateSources(SalesLine, ItemLedgerEntry);
        LedgerCount := ItemLedgerEntry.Count();
        Request := PublishedExampleData("Message Type ori"::"Inventory.Reservation.Create");
        Request.Replace('source', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Replace('itemLedgerEntryNo', ItemLedgerEntry."Entry No.");
        ExecuteReservation(Request, false, Response);
        AssertStatus(Response, 'Success');
        FilterSalesReservations(SalesLine, ReservationEntry);
        Assert.AreEqual(1, ReservationEntry.Count(), 'One demand row is paired.');
        ReservationEntry.FindFirst();
        PairNo := ReservationEntry."Entry No.";
        OppositeEntry.Get(PairNo, not ReservationEntry.Positive);
        Assert.AreEqual(ItemLedgerEntry."Entry No.", OppositeEntry."Source Ref. No.", 'Explicit owned stock is paired.');
        Assert.AreEqual(2, OppositeEntry."Quantity (Base)", 'Published quantity is reserved.');
        Request := PublishedExampleData("Message Type ori"::"Inventory.Reservation.Get");
        Request.Replace('source', SourceObject('SalesLine', SalesLine.SystemId));
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        TrackingRead.ReadReservations(TempArgument);
        Response := TempArgument.GetResponseJson();
        AssertStatus(Response, 'Success');
        Response.Get('entries', Token);
        Assert.AreEqual(1, Token.AsArray().Count(), 'Source filter selects only the demand side.');
        Assert.AreEqual(1, ReservationEntry.Count(), 'Reading does not change the pair.');
        Request := PublishedExampleData("Message Type ori"::"Inventory.Reservation.Cancel");
        Request.Replace('source', SourceObject('SalesLine', SalesLine.SystemId));
        ExecuteReservation(Request, true, Response);
        AssertStatus(Response, 'Success');
        ReservationEntry.Reset();
        ReservationEntry.SetRange("Entry No.", PairNo);
        Assert.IsTrue(ReservationEntry.IsEmpty(), 'Native cancellation removes both sides.');
        Assert.AreEqual(LedgerCount, ItemLedgerEntry.Count(), 'No additional inventory posting.');
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

    local procedure EnableInventoryDocumentReservation()
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.Get();
        InventorySetup.Validate("Allow Invt. Doc. Reservation", true);
        InventorySetup.Modify(true);
    end;

    local procedure AssertNativeBindingRefusal(Request: JsonObject; ItemNo: Code[20]; Ledger: Record "Item Ledger Entry")
    var
        Entries: Record "Reservation Entry";
        Response: JsonObject;
        RemainingQuantity: Decimal;
        Source: JsonToken;
        SourceId: JsonToken;
    begin
        Request.Get('source', Source);
        Source.AsObject().Get('systemId', SourceId);
        Assert.AreNotEqual('00000000-0000-0000-0000-000000000000', SourceId.AsValue().AsText(), 'Refusal must exercise the real native source, not a missing record.');
        RemainingQuantity := Ledger."Remaining Quantity";
        asserterror ExecuteReservation(Request, false, Response);
        Assert.ExpectedError('not a true demand or supply');
        Entries.SetRange("Item No.", ItemNo);
        Assert.IsTrue(Entries.IsEmpty(), 'Native binding refusal leaves no reservation or tracking pair.');
        Ledger.Get(Ledger."Entry No.");
        Assert.AreEqual(RemainingQuantity, Ledger."Remaining Quantity", 'Refusal does not consume posted supply.');
    end;

    local procedure CreateSources(var SalesLine: Record "Sales Line"; var ItemLedgerEntry: Record "Item Ledger Entry")
    begin
        CreateSourcesAtLocation(SalesLine, ItemLedgerEntry, '');
    end;

    local procedure CreateSourcesAtLocation(var SalesLine: Record "Sales Line"; var ItemLedgerEntry: Record "Item Ledger Entry"; LocationCode: Code[10])
    var
        Item: Record Item;
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        SalesHeader: Record "Sales Header";
    begin
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJournalBatch, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(ItemJournalLine, ItemJournalTemplate.Name, ItemJournalBatch.Name, ItemJournalLine."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.FindLast();
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 10);
        SalesLine.Validate("Location Code", LocationCode);
        SalesLine.Modify(true);
    end;

    local procedure CreateRequest(SalesLine: Record "Sales Line"; ItemLedgerEntry: Record "Item Ledger Entry"; Quantity: Decimal) Request: JsonObject
    begin
        Request.Add('source', SourceObject('SalesLine', SalesLine.SystemId));
        Request.Add('supply', SourceObject('ItemLedgerEntry', ItemLedgerEntry.SystemId));
        Request.Add('quantity', Quantity);
    end;

    local procedure SourceObject(TypeName: Text; SourceId: Guid) Source: JsonObject
    begin
        Source.Add('type', TypeName);
        Source.Add('systemId', Format(SourceId, 0, 4));
    end;

    local procedure ExecuteReservation(Request: JsonObject; CancelMode: Boolean; var Response: JsonObject)
    var
        TempArgument: Record "Message Argument ori" temporary;
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        if CancelMode then
            ReservationWrite.SetCancelMode();
        ReservationWrite.Run(TempArgument);
        Response := TempArgument.GetResponseJson();
    end;

    local procedure FilterSalesReservations(SalesLine: Record "Sales Line"; var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry.Reset();
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
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
