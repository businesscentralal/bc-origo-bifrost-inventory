namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.Tracking.Assign. Assigns lot, serial, or package tracking.
/// </summary>
codeunit 70013470 "Tracking Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assigns lot, serial, or package tracking to an item document line.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assign lot number, assign serial number, assign package number, item tracking', Comment = 'is-IS=úthluta lotunúmeri, úthluta raðnúmeri, úthluta pakkanúmeri, vörurakning';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Writes item tracking on a document line. Does not post the document.', Comment = 'is-IS=Skráir vörurakningu á línu skjals. Bókar ekki skjalið.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ReservationEntry: Record "Reservation Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        LotNo: Code[50];
        SerialNo: Code[50];
        PackageNo: Code[50];
        Quantity: Decimal;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemNo', Token) and Token.IsValue() then
            ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo));
        if RequestJson.Get('lotNo', Token) and Token.IsValue() then
            LotNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(LotNo));
        if RequestJson.Get('serialNo', Token) and Token.IsValue() then
            SerialNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(SerialNo));
        if RequestJson.Get('packageNo', Token) and Token.IsValue() then
            PackageNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(PackageNo));
        if RequestJson.Get('quantity', Token) and Token.IsValue() then
            Quantity := Token.AsValue().AsDecimal();

        if ItemNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'itemNo is required.', 'itemNo', '', '', '');
            exit;
        end;
        if (LotNo = '') and (SerialNo = '') and (PackageNo = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'lotNo, serialNo, or packageNo is required.', '', '', '', '');
            exit;
        end;

        ReservationEntry.Init();
        ReservationEntry."Item No." := ItemNo;
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Serial No." := SerialNo;
        ReservationEntry."Package No." := PackageNo;
        ReservationEntry."Quantity (Base)" := Quantity;
        ReservationEntry.Positive := Quantity >= 0;
        ReservationEntry.Insert(true);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', ReservationEntry."Entry No.");
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('lotNo', LotNo);
        ResponseJson.Add('serialNo', SerialNo);
        ResponseJson.Add('packageNo', PackageNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
