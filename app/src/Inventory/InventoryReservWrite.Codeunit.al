namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Creates explicitly paired manual reservations and cancels only selected source reservations.</summary>
codeunit 10036915 "Inventory Reserv. Write ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        CancelReservation: Boolean;

    trigger OnRun()
    begin
        if CancelReservation then
            Cancel(Rec)
        else
            Create(Rec);
    end;

    /// <summary>Selects cancellation for this isolated invocation.</summary>
    procedure SetCancelMode()
    begin
        CancelReservation := true;
    end;

    local procedure Create(var Argument: Record "Message Argument ori")
    var
        SourceSpecification: Record "Tracking Specification";
        SupplySpecification: Record "Tracking Specification";
        SourceEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Resolver: Codeunit "Inventory Source Resolve ori";
        Reader: Codeunit "Request Value Reader ori";
        ReservationManagement: Codeunit "Reservation Management";
        SupplyManagement: Codeunit "Reservation Management";
        SourceRef: RecordRef;
        SupplyRef: RecordRef;
        SourceDirection: Enum "Transfer Direction";
        SupplyDirection: Enum "Transfer Direction";
        Request: JsonObject;
        Response: JsonObject;
        Quantity: Decimal;
        QuantityBase: Decimal;
        ExpectedDate: Date;
        InvalidPairErr: Label 'Select distinct, opposite reservation sources for the same item, variant and location.', Comment = 'is-IS=Veldu aðskilda, gagnstæða frátektaruppruna fyrir sömu vöru, afbrigði og birgðageymslu.';
        InvalidQuantityErr: Label 'Reservation quantity must be positive and available on both sources.', Comment = 'is-IS=Frátekið magn verður að vera jákvætt og tiltækt á báðum upprunum.';
    begin
        Request := Argument.GetRequestJson();
        if not Resolver.Resolve(Argument, Request, 'source', true, SourceRef, SourceSpecification, SourceDirection) then
            exit;
        if not Resolver.Resolve(Argument, Request, 'supply', false, SupplyRef, SupplySpecification, SupplyDirection) then
            exit;
        if not Reader.TryReadDecimal(Argument, Request, 'quantity', true, Quantity) then
            exit;
        if not Reader.TryReadDate(Argument, Request, 'expectedDate', false, ExpectedDate) then
            exit;
        if (SourceRef.RecordId = SupplyRef.RecordId) or
           (SourceSpecification."Item No." <> SupplySpecification."Item No.") or
           (SourceSpecification."Variant Code" <> SupplySpecification."Variant Code") or
           (SourceSpecification."Location Code" <> SupplySpecification."Location Code")
        then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidPairErr, 'supply', '', '', '');
            exit;
        end;
        SourceSpecification.TestField("Qty. per Unit of Measure");
        QuantityBase := Round(Quantity * SourceSpecification."Qty. per Unit of Measure", 0.00001);
        if (Quantity <= 0) or (QuantityBase <= 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidQuantityErr, 'quantity', Format(Quantity, 0, 9), '>0', '');
            exit;
        end;
        SourceEntry.TransferFields(SourceSpecification);
        SupplyEntry.TransferFields(SupplySpecification);
        ReservationManagement.SetReservSource(SourceRef, SourceDirection);
        SupplyManagement.SetReservSource(SupplyRef, SupplyDirection);
        if SupplyRef.Number = Database::"Item Ledger Entry" then begin
            SupplyRef.SetTable(ItemLedgerEntry);
            ItemLedgerEntry.TestField(Open, true);
            ItemLedgerEntry.TestField("Drop Shipment", false);
            if (ItemLedgerEntry.Positive <> ReservationManagement.IsPositive()) or
               (ReservationManagement.FindUnfinishedSpecialOrderSalesNo(ItemLedgerEntry) <> '') then
                Error(InvalidPairErr);
        end else
            if SourceRef.Number <> Database::"Item Ledger Entry" then
                if ReservationManagement.IsPositive() = SupplyManagement.IsPositive() then
                    Error(InvalidPairErr);
        if (QuantityBase > AvailableQuantity(SourceEntry)) or (QuantityBase > AvailableQuantity(SupplyEntry)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidQuantityErr, 'quantity', Format(Quantity, 0, 9), '', '');
            exit;
        end;
        // Native source adapters call Create Reserv. Entry and preserve reservation pairing and UOM.
        if SourceRef.Number = Database::"Item Ledger Entry" then begin
            SourceRef.SetTable(ItemLedgerEntry);
            ItemLedgerEntry.TestField(Open, true);
            ItemLedgerEntry.TestField("Drop Shipment", false);
            if (SupplyRef.Number = Database::"Item Ledger Entry") or (ItemLedgerEntry.Positive <> SupplyManagement.IsPositive()) then
                Error(InvalidPairErr);
            SupplyManagement.SetTrackingFromReservEntry(SourceEntry);
            SupplyManagement.CreateReservation(SourceSpecification.Description, ExpectedDate, 0, QuantityBase, SourceSpecification);
        end else begin
            ReservationManagement.SetTrackingFromReservEntry(SupplyEntry);
            ReservationManagement.CreateReservation(SourceSpecification.Description, ExpectedDate, Quantity, QuantityBase, SupplySpecification);
        end;
        Response.Add('status', 'Success');
        Response.Add('quantity', Quantity);
        Response.Add('quantityBase', QuantityBase);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AvailableQuantity(SourceEntry: Record "Reservation Entry"): Decimal
    var
        ReservedEntry: Record "Reservation Entry";
        ReservationManagement: Codeunit "Reservation Management";
        SourceQuantity: Decimal;
    begin
        SourceQuantity := ReservationManagement.SourceQuantity(SourceEntry, false);
        ReservedEntry := SourceEntry;
        ReservedEntry.SetPointerFilter();
        ReservedEntry.SetRange("Reservation Status", ReservedEntry."Reservation Status"::Reservation);
        ReservedEntry.CalcSums("Quantity (Base)");
        exit(Abs(SourceQuantity) - Abs(ReservedEntry."Quantity (Base)"));
    end;

    local procedure Cancel(var Argument: Record "Message Argument ori")
    var
        SourceSpecification: Record "Tracking Specification";
        ReservationEntry: Record "Reservation Entry";
        TempEntries: Record "Reservation Entry" temporary;
        Resolver: Codeunit "Inventory Source Resolve ori";
        Reader: Codeunit "Request Value Reader ori";
        ReservationManagement: Codeunit "Reservation Management";
        ReservationEngine: Codeunit "Reservation Engine Mgt.";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        EntryNo: Decimal;
        Count: Integer;
        InvalidEntryErr: Label 'entryNo must identify a reservation on the specified source.', Comment = 'is-IS=entryNo verður að vísa í frátekt á tilgreindum uppruna.';
    begin
        Request := Argument.GetRequestJson();
        // With entry-only cancellation, resolve the demand-side pointer before any native write.
        if not Request.Contains('source') and Request.Get('entryNo', Token) then begin
            if not Reader.TryReadDecimal(Argument, Request, 'entryNo', true, EntryNo) then
                exit;
            if (EntryNo <= 0) or (EntryNo <> Round(EntryNo, 1)) or (EntryNo > 2147483647) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), 'positive integer', '');
                exit;
            end;
            ReservationEntry.SetRange("Entry No.", EntryNo);
            ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
            if not ReservationEntry.FindFirst() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), '', '');
                exit;
            end;
            if not Resolver.ResolveEntry(Argument, ReservationEntry, true, SourceRef, SourceSpecification, Direction) then
                exit;
        end else
            if not Resolver.Resolve(Argument, Request, 'source', true, SourceRef, SourceSpecification, Direction) then
                exit;
        ReservationEntry.Reset();
        ReservationEntry.TransferFields(SourceSpecification);
        ReservationEntry.SetPointerFilter();
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if Request.Get('entryNo', Token) then begin
            if not Reader.TryReadDecimal(Argument, Request, 'entryNo', true, EntryNo) then
                exit;
            if (EntryNo <= 0) or (EntryNo <> Round(EntryNo, 1)) or (EntryNo > 2147483647) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), 'positive integer', '');
                exit;
            end;
            ReservationEntry.SetRange("Entry No.", EntryNo);
            if ReservationEntry.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), '', '');
                exit;
            end;
        end;
        if ReservationEntry.FindSet() then
            repeat
                TempEntries := ReservationEntry;
                TempEntries.Insert();
            until ReservationEntry.Next() = 0;
        if TempEntries.FindSet() then
            repeat
                ReservationEntry.Reset();
                ReservationEntry := TempEntries;
                ReservationEntry.SetPointerFilter();
                ReservationEntry.SetRange("Entry No.", TempEntries."Entry No.");
                ReservationEntry.SetRange(Positive, TempEntries.Positive);
                ReservationManagement.SetReservSource(SourceRef, Direction);
                ReservationEngine.CancelReservation(TempEntries);
                Count += 1;
            until TempEntries.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('entriesCancelled', Count);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
