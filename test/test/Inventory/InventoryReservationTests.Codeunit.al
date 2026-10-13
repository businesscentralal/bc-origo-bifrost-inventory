namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
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
