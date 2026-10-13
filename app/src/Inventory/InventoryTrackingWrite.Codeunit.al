namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>Runs source-bound tracking changes through the native tracking page and reservation engine.</summary>
codeunit 10036914 "Inventory Tracking Write ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        DeleteTracking: Boolean;

    trigger OnRun()
    begin
        Execute(Rec);
    end;

    /// <summary>Selects removal of tracking rather than assignment for this invocation.</summary>
    procedure SetDeleteMode()
    begin
        DeleteTracking := true;
    end;

    local procedure Execute(var Argument: Record "Message Argument ori")
    var
        SourceSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        Resolver: Codeunit "Inventory Source Resolve ori";
        TrackingLines: Page "Item Tracking Lines";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
        Entry: JsonToken;
        Count: Integer;
        InvalidSourceErr: Label 'Tracking requires a sales, purchase, transfer, assembly or item journal source.', Comment = 'is-IS=Vörurakning krefst sölu-, innkaupa-, flutnings-, samsetningar- eða vöruuppbókaruppruna.';
        InvalidEntriesErr: Label 'entries must contain between 1 and 200 tracking objects.', Comment = 'is-IS=entries verður að innihalda á milli 1 og 200 rakningarhluti.';
    begin
        Request := Argument.GetRequestJson();
        if not Resolver.Resolve(Argument, Request, 'source', true, SourceRef, SourceSpecification, Direction) then
            exit;
        if not (SourceRef.Number in [Database::"Sales Line", Database::"Purchase Line", Database::"Transfer Line", Database::"Assembly Header", Database::"Assembly Line", Database::"Item Journal Line"]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidSourceErr, 'source.type', '', '', '');
            exit;
        end;
        TrackingLines.SetBlockCommit(true);
        if SourceRef.Number = Database::"Transfer Line" then
            TrackingLines.SetRunMode("Item Tracking Run Mode"::Transfer);
        if DeleteTracking then begin
            if not DeleteEntries(Argument, Request, SourceRef, Direction, SourceSpecification, TrackingLines, Count) then
                exit;
        end else begin
            if Request.Get('entries', Token) then
                if Token.IsArray() then
                    Entries := Token.AsArray();
            if (Entries.Count() < 1) or (Entries.Count() > 200) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntriesErr, 'entries', '', 'array', '');
                exit;
            end;
            foreach Entry in Entries do begin
                if not Entry.IsObject() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntriesErr, 'entries', '', 'object', '');
                    exit;
                end;
                Count += 1;
                TempTrackingSpecification := SourceSpecification;
                TempTrackingSpecification."Entry No." := Count;
                if not ReadTrackingEntry(Argument, Entry.AsObject(), TempTrackingSpecification) then
                    exit;
                TempTrackingSpecification.Insert();
            end;
            TrackingLines.RegisterItemTrackingLines(SourceSpecification, WorkDate(), TempTrackingSpecification);
        end;
        Response.Add('status', 'Success');
        if DeleteTracking then
            Response.Add('entriesDeleted', Count)
        else
            Response.Add('entriesAssigned', Count);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadTrackingEntry(var Argument: Record "Message Argument ori"; Entry: JsonObject; var Specification: Record "Tracking Specification"): Boolean
    var
        Resolver: Codeunit "Inventory Source Resolve ori";
        Reader: Codeunit "Request Value Reader ori";
        LotNo: Text;
        SerialNo: Text;
        PackageNo: Text;
        Quantity: Decimal;
        ExpirationDate: Date;
        InvalidTrackingErr: Label 'Specify a tracking number and a positive quantity; a serial number requires one base unit.', Comment = 'is-IS=Tilgreindu rakningarnúmer og jákvætt magn; raðnúmer krefst einnar grunneiningar.';
    begin
        if not Resolver.ReadText(Argument, Entry, 'lotNo', false, LotNo) then
            exit(false);
        if not Resolver.ReadText(Argument, Entry, 'serialNo', false, SerialNo) then
            exit(false);
        if not Resolver.ReadText(Argument, Entry, 'packageNo', false, PackageNo) then
            exit(false);
        if not Reader.TryReadDecimal(Argument, Entry, 'quantity', true, Quantity) then
            exit(false);
        if not Reader.TryReadDate(Argument, Entry, 'expirationDate', false, ExpirationDate) then
            exit(false);
        if ((LotNo = '') and (SerialNo = '') and (PackageNo = '')) or (Quantity <= 0) or
           ((SerialNo <> '') and (Quantity <> 1)) or
           (StrLen(LotNo) > MaxStrLen(Specification."Lot No.")) or
           (StrLen(SerialNo) > MaxStrLen(Specification."Serial No.")) or
           (StrLen(PackageNo) > MaxStrLen(Specification."Package No."))
        then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidTrackingErr, 'entries', '', '', '');
            exit(false);
        end;
        Specification."Lot No." := CopyStr(LotNo, 1, MaxStrLen(Specification."Lot No."));
        Specification."Serial No." := CopyStr(SerialNo, 1, MaxStrLen(Specification."Serial No."));
        Specification."Package No." := CopyStr(PackageNo, 1, MaxStrLen(Specification."Package No."));
        Specification."Quantity (Base)" := Quantity;
        Specification."Expiration Date" := ExpirationDate;
        exit(true);
    end;

    local procedure DeleteEntries(var Argument: Record "Message Argument ori"; Request: JsonObject; SourceRef: RecordRef; Direction: Enum "Transfer Direction"; SourceSpecification: Record "Tracking Specification"; var TrackingLines: Page "Item Tracking Lines"; var Count: Integer): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        TempSelected: Record "Reservation Entry" temporary;
        Specification: Record "Tracking Specification";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
        ReservationManagement: Codeunit "Reservation Management";
        Token: JsonToken;
        EntryToken: JsonToken;
        EntryNumbers: JsonArray;
        EntryNo: Integer;
        InvalidEntryErr: Label 'Every entry number must identify tracking on the specified source.', Comment = 'is-IS=Hvert færslunúmer verður að vísa í rakningu á tilgreindum uppruna.';
    begin
        ReservationEntry.TransferFields(SourceSpecification);
        ReservationEntry.SetPointerFilter();
        if Request.Get('entryNos', Token) then begin
            if not Token.IsArray() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNos', '', 'array of integers', '');
                exit(false);
            end;
            EntryNumbers := Token.AsArray();
            foreach EntryToken in EntryNumbers do begin
                if not ReadEntryNo(EntryToken, EntryNo) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNos', '', 'positive integer', '');
                    exit(false);
                end;
                ReservationEntry.SetRange("Entry No.", EntryNo);
                if not ReservationEntry.FindFirst() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidEntryErr, 'entryNos', Format(EntryNo, 0, 9), '', '');
                    exit(false);
                end;
                if not ReservationEntry.TrackingExists() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidEntryErr, 'entryNos', Format(EntryNo, 0, 9), '', '');
                    exit(false);
                end;
                TempSelected := ReservationEntry;
                if not TempSelected.Get(ReservationEntry."Entry No.", ReservationEntry.Positive) then
                    TempSelected.Insert();
            end;
        end else
            if ReservationEntry.FindSet() then
                repeat
                    if ReservationEntry.TrackingExists() then begin
                        TempSelected := ReservationEntry;
                        TempSelected.Insert();
                    end;
                until ReservationEntry.Next() = 0;
        // Resolve and validate every requested entry before the first write.
        TrackingLines.SetSourceSpec(SourceSpecification, WorkDate());
        if TempSelected.FindSet() then
            repeat
                ItemTrackingManagement.CreateTrackingSpecification(TempSelected, Specification);
                ReservationEntry.Reset();
                ReservationEntry.TransferFields(Specification);
                ReservationEntry.SetPointerFilter();
                ReservationEntry.SetRange("Entry No.", TempSelected."Entry No.");
                ReservationEntry.SetRange(Positive, TempSelected.Positive);
                ReservationManagement.SetReservSource(SourceRef, Direction);
                ReservationManagement.SetItemTrackingHandling(1);
                ReservationManagement.DeleteReservEntries(true, 0, ReservationEntry);
                Count += 1;
            until TempSelected.Next() = 0;
        exit(true);
    end;

    [TryFunction]
    local procedure ReadEntryNo(Token: JsonToken; var EntryNo: Integer)
    begin
        EntryNo := Token.AsValue().AsInteger();
        if EntryNo <= 0 then
            Error(Format(EntryNo, 0, 9));
    end;
}
