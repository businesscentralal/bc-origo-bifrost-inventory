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
codeunit 10076925 "Inventory Tracking Write ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        ResponseEntry: Record "Reservation Entry";
        DeleteTracking: Boolean;
        TrackingNextStepLbl: Label 'Read Inventory.Tracking.Get for the source and send valid tracking entries for that source.', Comment = 'is-IS=Lestu Inventory.Tracking.Get fyrir upprunann og sendu gildar rakningarfærslur fyrir þann uppruna.';
        SourceExpectedLbl: Label 'A SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine or ItemJournalLine source.', Comment = 'is-IS=Uppruni af gerðinni SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine eða ItemJournalLine.';
        EntryExpectedLbl: Label 'A tracking number and positive base quantity; serial tracking uses one base unit.', Comment = 'is-IS=Rakningarnúmer og jákvætt grunnmagn; raðnúmerarakning notar eina grunneiningu.';

    trigger OnRun()
    begin
        Execute(Rec);
    end;

    /// <summary>Combines the company switch, native reservation writes and permission to at least one supported source table.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
    begin
        if not Gate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false) then
            exit(false);
        exit(HasAnySourceWritePermission());
    end;

    local procedure HasAnySourceWritePermission(): Boolean
    begin
        exit(HasSourceWritePermission(Database::"Sales Line") or HasSourceWritePermission(Database::"Purchase Line") or
             HasSourceWritePermission(Database::"Transfer Line") or HasSourceWritePermission(Database::"Assembly Header") or
             HasSourceWritePermission(Database::"Assembly Line") or HasSourceWritePermission(Database::"Item Journal Line"));
    end;

    /// <summary>Uses the same discovery gate before resolving and checking the selected source at execution.</summary>
    procedure AssertEnabled(var Argument: Record "Message Argument ori"): Boolean
    var
        Gate: Codeunit "Inventory Domain Gate ori";
        PermissionDeniedErr: Label 'Permission denied for the supported item tracking source lines.', Comment = 'is-IS=Heimild hafnað fyrir studdar upprunalínur vörurakningar.';
        PermissionNextStepLbl: Label 'Ask an administrator for native read and write permission on the selected source line and reservation entries.', Comment = 'is-IS=Biddu kerfisstjóra um innbyggðar les- og ritheimildir á valdri upprunalínu og frátektarfærslum.';
    begin
        if not Gate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false) then
            exit(false);
        if HasAnySourceWritePermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, 'source', '', SourceExpectedLbl, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure HasSourceWritePermission(TableNo: Integer): Boolean
    var
        SourceRef: RecordRef;
    begin
        SourceRef.Open(TableNo);
        exit(SourceRef.ReadPermission() and SourceRef.WritePermission());
    end;

    /// <summary>Preserves native failure text with the exact source selector and actionable tracking context.</summary>
    procedure RespondWithFailure(var Argument: Record "Message Argument ori")
    var
        Parts: Codeunit "Inventory Contract Parts ori";
        Request: JsonObject;
        Source: JsonToken;
        Received: Text;
    begin
        Request := Argument.GetRequestJson();
        if Request.Get('source', Source) then
            Source.WriteTo(Received)
        else
            Received := '<missing>';
        Parts.RespondWithNativeContext(Argument, 'source', Received, SourceExpectedLbl, TrackingNextStepLbl);
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
        ItemTrackingManagement: Codeunit "Item Tracking Management";
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
        InvalidSourceErr: Label 'Tracking requires a sales, purchase, transfer, assembly or item journal source.', Comment = 'is-IS=Vörurakning krefst sölu-, innkaupa-, flutnings-, samsetningar- eða birgðabókarlínu.';
        InvalidEntriesErr: Label 'entries must contain between 1 and 200 tracking objects.', Comment = 'is-IS=entries verður að innihalda á milli 1 og 200 rakningarhluti.';
    begin
        Request := Argument.GetRequestJson();
        if not Resolver.Resolve(Argument, Request, 'source', true, SourceRef, SourceSpecification, Direction) then
            exit;
        if not (SourceRef.Number in [Database::"Sales Line", Database::"Purchase Line", Database::"Transfer Line", Database::"Assembly Header", Database::"Assembly Line", Database::"Item Journal Line"]) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidSourceErr, 'source.type', Format(SourceRef.Number, 0, 9), SourceExpectedLbl, TrackingNextStepLbl);
            exit;
        end;
        if not Resolver.ReadText(Argument, Request, 'itemNo', false, ItemNo) then
            exit;
        if (ItemNo <> '') and (UpperCase(ItemNo) <> SourceSpecification."Item No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, ItemMismatchErr, 'itemNo', ItemNo, SourceSpecification."Item No.", SelectSourceTxt);
            exit;
        end;
        ItemTrackingManagement.SetPointerFilter(SourceSpecification);
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
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntriesErr, 'entries', Format(Token), 'array', TrackingNextStepLbl);
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
                AssignedEntry.ReadIsolation(IsolationLevel::ReadCommitted);
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
        EntryNumbers: JsonArray;
        EntryToken: JsonToken;
        HasSelection: Boolean;
        SourceTrackingTxt: Label 'Tracking on the selected source.', Comment = 'is-IS=Rakning á völdum uppruna.';
        ReadTrackingTxt: Label 'Read Inventory.Tracking.Get for this source and send its unreserved ReservationEntry entryNo.', Comment = 'is-IS=Lestu Inventory.Tracking.Get fyrir þennan uppruna og sendu entryNo úr ReservationEntry sem er ekki frátekið.';
        EntryArrayExpectedLbl: Label 'An array of positive integers.', Comment = 'is-IS=Fylki jákvæðra heiltalna.';
        EntrySelectionExpectedLbl: Label '1..200 entry numbers; omit entryNo.', Comment = 'is-IS=1..200 færslunúmer; slepptu entryNo.';
        InvalidEntryErr: Label 'Every entry number must identify tracking on the specified source.', Comment = 'is-IS=Hvert færslunúmer verður að vísa í rakningu á tilgreindum uppruna.';
    begin
        ReservationEntry.TransferFields(SourceSpecification);
        ReservationEntry.SetPointerFilter();
        if (SourceRef.Number = Database::"Transfer Line") and (Direction = Direction::Inbound) then begin
            SourceRef.SetTable(TransferLine);
            TransferReserve.FindInboundReservEntry(TransferLine, ReservationEntry);
        end;
        ReservationEntry.LockTable();
        HasSelection := Request.Get('entryNos', Token);
        if HasSelection then begin
            if not Token.IsArray() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNos', Format(Token), EntryArrayExpectedLbl, ReadTrackingTxt);
                exit(false);
            end;
            EntryNumbers := Token.AsArray();
            if (EntryNumbers.Count() = 0) or (EntryNumbers.Count() > 200) or Request.Contains('entryNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidEntryErr, 'entryNos', Format(Token), EntrySelectionExpectedLbl, ReadTrackingTxt);
                exit(false);
            end;
        end else
            if Request.Get('entryNo', Token) then begin
                HasSelection := true;
                EntryNumbers.Add(Token);
            end;
        if HasSelection then
            foreach EntryToken in EntryNumbers do begin
                if not ReadEntryNo(EntryToken, EntryNo) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidEntryErr, 'entryNos', Format(EntryToken), 'positive integer', ReadTrackingTxt);
                    exit(false);
                end;
                ReservationEntry.SetRange("Entry No.", EntryNo);
                if not ReservationEntry.FindFirst() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, InvalidEntryErr, 'entryNo', Format(EntryNo, 0, 9), SourceTrackingTxt, ReadTrackingTxt);
                    exit(false);
                end;
                if not SelectEntry(Argument, ReservationEntry, TempSelected) then
                    exit(false);
            end
        else
            if ReservationEntry.FindSet() then
                repeat
                    if ReservationEntry.TrackingExists() then
                        if not SelectEntry(Argument, ReservationEntry, TempSelected) then
                            exit(false);
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

    local procedure SelectEntry(var Argument: Record "Message Argument ori"; Entry: Record "Reservation Entry"; var Selected: Record "Reservation Entry" temporary): Boolean
    var
        SelectionLimitExpectedLbl: Label 'At most 200 tracking entries.', Comment = 'is-IS=Að hámarki 200 rakningarfærslur.';
        UnreservedTrackingExpectedLbl: Label 'Unreserved tracking.', Comment = 'is-IS=Ófrátekin rakning.';
        InvalidEntryErr: Label 'Only unreserved tracking on the selected source can be removed.', Comment = 'is-IS=Aðeins er hægt að fjarlægja ófrátekna rakningu á völdum uppruna.';
        ReadTrackingTxt: Label 'Read Inventory.Tracking.Get for this source and select its unreserved tracking entries.', Comment = 'is-IS=Lestu Inventory.Tracking.Get fyrir þennan uppruna og veldu ófráteknar rakningarfærslur hans.';
    begin
        if not Entry.TrackingExists() or (Entry."Reservation Status" = Entry."Reservation Status"::Reservation) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, InvalidEntryErr, 'entryNo', Format(Entry."Entry No.", 0, 9), UnreservedTrackingExpectedLbl, ReadTrackingTxt);
            exit(false);
        end;
        if Selected.Get(Entry."Entry No.", Entry.Positive) then
            exit(true);
        if Selected.Count() >= 200 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, InvalidEntryErr, 'entryNos', '', SelectionLimitExpectedLbl, ReadTrackingTxt);
            exit(false);
        end;
        ResponseEntry := Entry;
        Selected := Entry;
        Selected.Insert();
        exit(true);
    end;

    [TryFunction]
    local procedure ReadEntryNo(Token: JsonToken; var EntryNo: Integer)
    begin
        EntryNo := Token.AsValue().AsInteger();
        if (EntryNo <= 0) or (Token.AsValue().AsDecimal() <> EntryNo) then
            Error(Format(EntryNo, 0, 9));
    end;
}
