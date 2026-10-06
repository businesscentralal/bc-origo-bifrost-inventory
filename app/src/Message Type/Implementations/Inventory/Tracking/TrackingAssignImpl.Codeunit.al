namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.Tracking.Assign. Creates an unposted tracking specification for a source line.
/// </summary>
codeunit 70013470 "Tracking Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Tracking Specification");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assigns lot, serial, and package tracking to a source line.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('assign lot, assign serial, assign package');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Assigns tracking to a source line. Serial quantity must be 1.');
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

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TrackingSpecification: Record "Tracking Specification";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        Quantity: Decimal;
        MissingItemErr: Label 'itemNo is required.', Locked = true;
        SerialQtyErr: Label 'quantity must be 1 when serialNo is specified.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingItemErr, 'itemNo', '', '', '');
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(ItemNo));
        Quantity := 1;
        if RequestJson.Get('quantity', Token) then
            Quantity := Token.AsValue().AsDecimal();
        TrackingSpecification.Init();
        TrackingSpecification."Item No." := ItemNo;
        TrackingSpecification."Quantity (Base)" := Quantity;
        if RequestJson.Get('serialNo', Token) then
            TrackingSpecification."Serial No." := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TrackingSpecification."Serial No."));
        if RequestJson.Get('lotNo', Token) then
            TrackingSpecification."Lot No." := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TrackingSpecification."Lot No."));
        if RequestJson.Get('packageNo', Token) then
            TrackingSpecification."Package No." := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TrackingSpecification."Package No."));
        if (TrackingSpecification."Serial No." <> '') and (Quantity <> 1) then begin
            Argument.RespondWithError(SerialQtyErr);
            exit;
        end;
        TrackingSpecification.Insert(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', TrackingSpecification."Entry No.");
        ResponseJson.Add('itemNo', TrackingSpecification."Item No.");
        ResponseJson.Add('serialNo', TrackingSpecification."Serial No.");
        ResponseJson.Add('lotNo', TrackingSpecification."Lot No.");
        ResponseJson.Add('packageNo', TrackingSpecification."Package No.");
        ResponseJson.Add('quantity', TrackingSpecification."Quantity (Base)");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
