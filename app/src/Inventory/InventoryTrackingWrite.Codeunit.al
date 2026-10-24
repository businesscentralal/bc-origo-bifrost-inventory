namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>Runs source-bound tracking changes through the native tracking page and reservation engine.</summary>
codeunit 10076925 "Inventory Tracking Write ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ResponseEntry: Record "Reservation Entry";
        DeleteTracking: Boolean;
        TrackingNextStepLbl: Label 'Read Inventory.Tracking.Get for the source and send valid tracking entries for that source.', Comment = 'is-IS=Lestu Inventory.Tracking.Get fyrir upprunann og sendu gildar rakningarfærslur fyrir þann uppruna.';
        SourceExpectedLbl: Label 'A SalesLine, PurchaseLine or TransferLine source.', Comment = 'is-IS=Uppruni af gerðinni SalesLine, PurchaseLine eða TransferLine.';
        EntryExpectedLbl: Label 'A tracking number and positive base quantity; serial tracking uses one base unit.', Comment = 'is-IS=Rakningarnúmer og jákvætt grunnmagn; raðnúmerarakning notar eina grunneiningu.';

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
        AssignedEntry: Record "Reservation Entry";
        SourceSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        Resolver: Codeunit "Inventory Tracking Read ori";
        TrackingLines: Page "Item Tracking Lines";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
        Response: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
        Entry: JsonToken;
        ItemNo: Text;
        Count: Integer;
        ItemMismatchErr: Label 'itemNo does not match the selected source line.', Comment = 'is-IS=itemNo passar ekki við valda upprunalínu.';
        SelectSourceTxt: Label 'Use the item on the selected source line.', Comment = 'is-IS=Notaðu vöruna á valdri upprunalínu.';
        InvalidSourceErr: Label 'Tracking requires a sales, purchase or transfer line source.', Comment = 'is-IS=Vörurakning krefst sölu-, innkaupa- eða flutningslínu.';
        InvalidEntriesErr: Label 'entries must contain between 1 and 200 tracking objects.', Comment = 'is-IS=entries verður að innihalda á milli 1 og 200 rakningarhluti.';
    begin
        Request := Argument.GetRequestJson();
        if not Resolver.Resolve(Argument, Request, 'source', true, SourceRef, SourceSpecification, Direction) then
            exit;
        if not (SourceRef.Number in [Database::"Sales Line", Database::"Purchase Line", Database::"Transfer Line"]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidSourceErr, 'source.type', Format(SourceRef.Number, 0, 9), SourceExpectedLbl, TrackingNextStepLbl);
            exit;
        end;
        if not Resolver.ReadText(Argument, Request, 'itemNo', false, ItemNo) then
            exit;
        if (ItemNo <> '') and (UpperCase(ItemNo) <> SourceSpecification."Item No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, ItemMismatchErr, 'itemNo', ItemNo, SourceSpecification."Item No.", SelectSourceTxt);
            exit;
        end;
        TrackingLines.SetBlockCommit(true);
        if SourceRef.Number = Database::"Transfer Line" then
            TrackingLines.SetRunMode("Item Tracking Run Mode"::Transfer);
        if DeleteTracking then begin
            if not DeleteEntries(Argument, Request, SourceRef, Direction, SourceSpecification, TrackingLines, Count) then
                exit;
        end else begin
            if Request.Get('entries', Token) then begin
                if Token.IsArray() then
                    Entries := Token.AsArray();
            end else
                Entries.Add(Request);
            if (Entries.Count() < 1) or (Entries.Count() > 200) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntriesErr, 'entries', Format(Token), InvalidEntriesErr, TrackingNextStepLbl);
                exit;
            end;
            foreach Entry in Entries do begin
                if not Entry.IsObject() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntriesErr, 'entries', Format(Entry), 'object', TrackingNextStepLbl);
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
            if Count = 1 then begin
                AssignedEntry.TransferFields(SourceSpecification);
                AssignedEntry.SetPointerFilter();
                AssignedEntry.SetRange("Lot No.", TempTrackingSpecification."Lot No.");
                AssignedEntry.SetRange("Serial No.", TempTrackingSpecification."Serial No.");
                AssignedEntry.SetRange("Package No.", TempTrackingSpecification."Package No.");
                if AssignedEntry.FindFirst() then
                    Response.Add('entryNo', AssignedEntry."Entry No.");
                Response.Add('itemNo', SourceSpecification."Item No.");
                Response.Add('lotNo', TempTrackingSpecification."Lot No.");
                Response.Add('serialNo', TempTrackingSpecification."Serial No.");
                Response.Add('packageNo', TempTrackingSpecification."Package No.");
                Response.Add('quantity', TempTrackingSpecification."Quantity (Base)");
            end;
        end;
        Response.Add('status', 'Success');
        if DeleteTracking then begin
            Response.Add('entriesDeleted', Count);
            Response.Add('entryNo', ResponseEntry."Entry No.");
            Response.Add('itemNo', ResponseEntry."Item No.");
            Response.Add('lotNo', ResponseEntry."Lot No.");
            Response.Add('serialNo', ResponseEntry."Serial No.");
            Response.Add('packageNo', ResponseEntry."Package No.");
        end else
            Response.Add('entriesAssigned', Count);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadTrackingEntry(var Argument: Record "Message Argument ori"; Entry: JsonObject; var Specification: Record "Tracking Specification"): Boolean
    var
        Resolver: Codeunit "Inventory Tracking Read ori";
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
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidTrackingErr, 'entries', Format(Entry), EntryExpectedLbl, TrackingNextStepLbl);
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
        TransferLine: Record "Transfer Line";
        TempSelected: Record "Reservation Entry" temporary;
        Specification: Record "Tracking Specification";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
        ReservationManagement: Codeunit "Reservation Management";
        TransferReserve: Codeunit "Transfer Line-Reserve";
        Token: JsonToken;
        EntryNo: Integer;
        SourceTrackingTxt: Label 'Tracking on the selected source.', Comment = 'is-IS=Rakning á völdum uppruna.';
        UnreservedTrackingTxt: Label 'Unreserved tracking on the selected source.', Comment = 'is-IS=Ófrátekin rakning á völdum uppruna.';
        ReadTrackingTxt: Label 'Read Inventory.Tracking.Get for this source and send its unreserved ReservationEntry entryNo.', Comment = 'is-IS=Lestu Inventory.Tracking.Get fyrir þennan uppruna og sendu entryNo úr ReservationEntry sem er ekki frátekið.';
        InvalidEntryErr: Label 'Every entry number must identify tracking on the specified source.', Comment = 'is-IS=Hvert færslunúmer verður að vísa í rakningu á tilgreindum uppruna.';
    begin
        ReservationEntry.TransferFields(SourceSpecification);
        ReservationEntry.SetPointerFilter();
        if (SourceRef.Number = Database::"Transfer Line") and (Direction = Direction::Inbound) then begin
            SourceRef.SetTable(TransferLine);
            TransferReserve.FindInboundReservEntry(TransferLine, ReservationEntry);
        end;
        if not Request.Get('entryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, InvalidEntryErr, 'entryNo', '', 'positive integer', ReadTrackingTxt);
            exit(false);
        end;
        if not ReadEntryNo(Token, EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNo', Format(Token), 'positive integer', ReadTrackingTxt);
            exit(false);
        end;
        ReservationEntry.LockTable();
        ReservationEntry.SetRange("Entry No.", EntryNo);
        if not ReservationEntry.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), SourceTrackingTxt, ReadTrackingTxt);
            exit(false);
        end;
        if not ReservationEntry.TrackingExists() or
           (ReservationEntry."Reservation Status" = ReservationEntry."Reservation Status"::Reservation)
        then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), UnreservedTrackingTxt, ReadTrackingTxt);
            exit(false);
        end;
        ResponseEntry := ReservationEntry;
        TempSelected := ReservationEntry;
        TempSelected.Insert();
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
