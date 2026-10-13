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
        if not Resolver.ResolveDocument(Argument, Request, true, SourceRef, SourceSpecification, SourceDirection) then
            exit;
        if not Request.Contains('supply') and not Request.Contains('itemLedgerEntryNo') then begin
            CreateFromInventory(Argument, Request, SourceRef, SourceSpecification, SourceDirection);
            exit;
        end;
        if not ResolveSupply(Argument, Request, SupplyRef, SupplySpecification, SupplyDirection) then
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
        if not ApplyRequestedTracking(Argument, Request, SourceRef.Number, SupplyRef.Number, SourceSpecification, SupplySpecification, QuantityBase) then
            exit;
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
        SourceEntry.SetPointerFilter();
        SourceEntry.SetRange("Reservation Status", SourceEntry."Reservation Status"::Reservation);
        if SourceEntry.FindLast() then
            Response.Add('entryNo', SourceEntry."Entry No.");
        Response.Add('status', 'Success');
        Response.Add('quantity', Quantity);
        Response.Add('quantityBase', QuantityBase);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CreateFromInventory(var Argument: Record "Message Argument ori"; Request: JsonObject; SourceRef: RecordRef; Specification: Record "Tracking Specification"; Direction: Enum "Transfer Direction")
    var
        Ledger: Record "Item Ledger Entry";
        SourceEntry: Record "Reservation Entry";
        ReservationEntry: Record "Reservation Entry";
        TempPartArgument: Record "Message Argument ori" temporary;
        Reader: Codeunit "Request Value Reader ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
        ReservationManagement: Codeunit "Reservation Management";
        Supplies: JsonArray;
        Supply: JsonObject;
        PartRequest: JsonObject;
        PartResponse: JsonObject;
        Response: JsonObject;
        EntryNumbers: JsonArray;
        Token: JsonToken;
        StatusToken: JsonToken;
        Quantity: Decimal;
        QuantityBase: Decimal;
        RemainingBase: Decimal;
        AvailableBase: Decimal;
        PartBase: Decimal;
        Lot: Text;
        Serial: Text;
        Package: Text;
        ErrorText: Text;
        SupplyErr: Label 'The requested quantity is not available in matching inventory for this source.', Comment = 'is-IS=Umbeðið magn er ekki tiltækt í samsvarandi birgðum fyrir þennan uppruna.';
        PermissionErr: Label 'Permission denied for inventory reservation data.', Comment = 'is-IS=Heimild hafnað fyrir birgðafrátektargögn.';
    begin
        if not Ledger.ReadPermission() or not ReservationEntry.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', '');
            exit;
        end;
        if not Reader.TryReadDecimal(Argument, Request, 'quantity', true, Quantity) then
            exit;
        if not Resolver.ReadText(Argument, Request, 'lotNo', false, Lot) or
           not Resolver.ReadText(Argument, Request, 'serialNo', false, Serial) or
           not Resolver.ReadText(Argument, Request, 'packageNo', false, Package)
        then
            exit;
        if (StrLen(Lot) > MaxStrLen(Ledger."Lot No.")) or (StrLen(Serial) > MaxStrLen(Ledger."Serial No.")) or (StrLen(Package) > MaxStrLen(Ledger."Package No.")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, SupplyErr, '', '', '', '');
            exit;
        end;
        Specification.TestField("Qty. per Unit of Measure");
        QuantityBase := Round(Quantity * Specification."Qty. per Unit of Measure", 0.00001);
        SourceEntry.TransferFields(Specification);
        ReservationManagement.SetReservSource(SourceRef, Direction);
        // Serialize reservation availability reads with the native writer. No direct table writes occur here.
        ReservationEntry.LockTable();
        if (Quantity <= 0) or (QuantityBase <= 0) or (QuantityBase > AvailableQuantity(SourceEntry)) or
           (SourceRef.Number = Database::"Item Ledger Entry") or not ReservationManagement.IsPositive()
        then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SupplyErr, 'quantity', Format(Quantity, 0, 9), '', '');
            exit;
        end;
        Ledger.SetRange("Item No.", Specification."Item No.");
        Ledger.SetRange("Variant Code", Specification."Variant Code");
        Ledger.SetRange("Location Code", Specification."Location Code");
        Ledger.SetRange(Open, true);
        Ledger.SetRange(Positive, true);
        Ledger.SetRange("Drop Shipment", false);
        Ledger.SetFilter("Remaining Quantity", '>0');
        if Request.Contains('lotNo') then
            Ledger.SetRange("Lot No.", Lot);
        if Request.Contains('serialNo') then
            Ledger.SetRange("Serial No.", Serial);
        if Request.Contains('packageNo') then
            Ledger.SetRange("Package No.", Package);
        Ledger.SetAutoCalcFields("Reserved Quantity");
        RemainingBase := QuantityBase;
        if Ledger.FindSet() then
            repeat
                AvailableBase := Ledger."Remaining Quantity" - Abs(Ledger."Reserved Quantity");
                if (AvailableBase > 0) and (RemainingBase > 0) and
                   (ReservationManagement.FindUnfinishedSpecialOrderSalesNo(Ledger) = '')
                then begin
                    PartBase := AvailableBase;
                    if PartBase > RemainingBase then
                        PartBase := RemainingBase;
                    if (Ledger."Serial No." <> '') and (PartBase <> 1) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SupplyErr, 'quantity', Format(Quantity, 0, 9), 'one base unit per serial', '');
                        exit;
                    end;
                    Clear(Supply);
                    Supply.Add('entryNo', Ledger."Entry No.");
                    Supply.Add('quantityBase', PartBase);
                    Supplies.Add(Supply);
                    RemainingBase -= PartBase;
                end;
            until (Ledger.Next() = 0) or (RemainingBase = 0);
        if RemainingBase <> 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SupplyErr, 'quantity', Format(Quantity, 0, 9), '', '');
            exit;
        end;
        // Validate the whole selection before the first native write, then use the explicit-pair path for every allocation.
        foreach Token in Supplies do begin
            Supply := Token.AsObject();
            PartRequest := Request.Clone().AsObject();
            Supply.Get('entryNo', StatusToken);
            PartRequest.Add('itemLedgerEntryNo', StatusToken);
            Supply.Get('quantityBase', StatusToken);
            PartBase := StatusToken.AsValue().AsDecimal();
            PartRequest.Replace('quantity', PartBase / Specification."Qty. per Unit of Measure");
            TempPartArgument.DeleteAll();
            TempPartArgument.Init();
            TempPartArgument.Version := Argument.Version;
            TempPartArgument.Insert(true);
            TempPartArgument.SetRequestJson(PartRequest);
            Create(TempPartArgument);
            PartResponse := TempPartArgument.GetResponseJson();
            if not PartResponse.Get('status', StatusToken) then
                Error(SupplyErr);
            if StatusToken.AsValue().AsText() <> 'Success' then begin
                PartResponse.WriteTo(ErrorText);
                Error(ErrorText);
            end;
            if PartResponse.Get('entryNo', StatusToken) then
                EntryNumbers.Add(StatusToken);
        end;
        Response.Add('status', 'Success');
        Response.Add('quantity', Quantity);
        Response.Add('quantityBase', QuantityBase);
        Response.Add('entryNos', EntryNumbers);
        if EntryNumbers.Count() = 1 then begin
            EntryNumbers.Get(0, Token);
            Response.Add('entryNo', Token);
        end;
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ResolveSupply(var Argument: Record "Message Argument ori"; Request: JsonObject; var SupplyRef: RecordRef; var Specification: Record "Tracking Specification"; var Direction: Enum "Transfer Direction"): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Resolver: Codeunit "Inventory Source Resolve ori";
        Reader: Codeunit "Request Value Reader ori";
        Supply: JsonObject;
        EntryNo: Decimal;
        InvalidSupplyErr: Label 'Specify an existing item ledger entry or an explicit supply source.', Comment = 'is-IS=Tilgreindu fyrirliggjandi vörufærslu eða skýran framboðsuppruna.';
        PermissionErr: Label 'Permission denied for the supply entry.', Comment = 'is-IS=Heimild hafnað fyrir framboðsfærsluna.';
    begin
        if Request.Contains('supply') then begin
            if Request.Contains('itemLedgerEntryNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidSupplyErr, 'supply', '', 'one supply selector', '');
                exit(false);
            end;
            exit(Resolver.Resolve(Argument, Request, 'supply', false, SupplyRef, Specification, Direction));
        end;
        if not Reader.TryReadDecimal(Argument, Request, 'itemLedgerEntryNo', true, EntryNo) then
            exit(false);
        if (EntryNo <= 0) or (EntryNo > 2147483647) or (EntryNo <> Round(EntryNo, 1)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidSupplyErr, 'itemLedgerEntryNo', Format(EntryNo, 0, 9), 'positive integer', '');
            exit(false);
        end;
        if not ItemLedgerEntry.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, 'itemLedgerEntryNo', '', '', '');
            exit(false);
        end;
        if not ItemLedgerEntry.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidSupplyErr, 'itemLedgerEntryNo', Format(EntryNo, 0, 9), '', '');
            exit(false);
        end;
        Supply.Add('type', 'ItemLedgerEntry');
        Supply.Add('systemId', Format(ItemLedgerEntry.SystemId, 0, 4));
        Request.Add('supply', Supply);
        exit(Resolver.Resolve(Argument, Request, 'supply', false, SupplyRef, Specification, Direction));
    end;

    local procedure ApplyRequestedTracking(var Argument: Record "Message Argument ori"; Request: JsonObject; SourceTable: Integer; SupplyTable: Integer; var Source: Record "Tracking Specification"; var Supply: Record "Tracking Specification"; QuantityBase: Decimal): Boolean
    var
        Resolver: Codeunit "Inventory Source Resolve ori";
        Lot: Text;
        Serial: Text;
        Package: Text;
        TrackingErr: Label 'Requested tracking must match the selected inventory entry; a serial reservation must be one base unit.', Comment = 'is-IS=Umbeðin rakning verður að passa við valda birgðafærslu; raðnúmerafrátekt verður að vera ein grunneining.';
    begin
        if not Resolver.ReadText(Argument, Request, 'lotNo', false, Lot) or
           not Resolver.ReadText(Argument, Request, 'serialNo', false, Serial) or
           not Resolver.ReadText(Argument, Request, 'packageNo', false, Package)
        then
            exit(false);
        if (StrLen(Lot) > MaxStrLen(Supply."Lot No.")) or (StrLen(Serial) > MaxStrLen(Supply."Serial No.")) or (StrLen(Package) > MaxStrLen(Supply."Package No.")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, TrackingErr, '', '', '', '');
            exit(false);
        end;
        if ((SupplyTable = Database::"Item Ledger Entry") and not TrackingMatches(Request, Supply, Lot, Serial, Package)) or
           ((SourceTable = Database::"Item Ledger Entry") and not TrackingMatches(Request, Source, Lot, Serial, Package)) or
           (((Serial <> '') or (Supply."Serial No." <> '') or (Source."Serial No." <> '')) and (QuantityBase <> 1))
        then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, TrackingErr, '', '', '', '');
            exit(false);
        end;
        if Request.Contains('lotNo') then
            Supply."Lot No." := CopyStr(Lot, 1, MaxStrLen(Supply."Lot No."));
        if Request.Contains('serialNo') then
            Supply."Serial No." := CopyStr(Serial, 1, MaxStrLen(Supply."Serial No."));
        if Request.Contains('packageNo') then
            Supply."Package No." := CopyStr(Package, 1, MaxStrLen(Supply."Package No."));
        exit(true);
    end;

    local procedure TrackingMatches(Request: JsonObject; Specification: Record "Tracking Specification"; Lot: Text; Serial: Text; Package: Text): Boolean
    begin
        exit((not Request.Contains('lotNo') or (Specification."Lot No." = Lot)) and
             (not Request.Contains('serialNo') or (Specification."Serial No." = Serial)) and
             (not Request.Contains('packageNo') or (Specification."Package No." = Package)));
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
        if not Request.Contains('source') and not Request.Contains('documentType') and Request.Get('entryNo', Token) then begin
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
            if not Resolver.ResolveDocument(Argument, Request, true, SourceRef, SourceSpecification, Direction) then
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
