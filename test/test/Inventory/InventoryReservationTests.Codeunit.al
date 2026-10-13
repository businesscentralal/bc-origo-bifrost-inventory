namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
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
    begin
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
    end;

    local procedure CreateSources(var SalesLine: Record "Sales Line"; var ItemLedgerEntry: Record "Item Ledger Entry")
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
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.FindLast();
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 10);
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
