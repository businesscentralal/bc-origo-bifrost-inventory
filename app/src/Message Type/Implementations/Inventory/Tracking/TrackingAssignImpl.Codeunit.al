namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.Tracking.Assign. Assigns lot, serial, and package through Item Tracking Management (codeunit 6500).
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
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
    begin
        Parameter.Add('name', 'itemNo');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Item number to track.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'lotNo');
        Parameter.Add('type', 'string');
        Parameter.Add('required', false);
        Parameter.Add('description', 'Lot number.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'serialNo');
        Parameter.Add('type', 'string');
        Parameter.Add('required', false);
        Parameter.Add('description', 'Serial number. Quantity must be 1.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'packageNo');
        Parameter.Add('type', 'string');
        Parameter.Add('required', false);
        Parameter.Add('description', 'Package number.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'quantity');
        Parameter.Add('type', 'number');
        Parameter.Add('required', false);
        Parameter.Add('description', 'Quantity in base units. Default 1.');
        Parameters.Add(Parameter);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('Inventory.Tracking.Delete');
        exit(true);
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
        Overview := 'Assigns lot, serial, and package tracking through Item Tracking Management.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Uses codeunit Item Tracking Management. Does not insert Tracking Specification directly.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TrackingSpecification: Record "Tracking Specification";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
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
        ItemTrackingManagement.InsertItemTracking(TrackingSpecification);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.Tracking.Assign');
        ResponseJson.Add('itemNo', TrackingSpecification."Item No.");
        ResponseJson.Add('serialNo', TrackingSpecification."Serial No.");
        ResponseJson.Add('lotNo', TrackingSpecification."Lot No.");
        ResponseJson.Add('packageNo', TrackingSpecification."Package No.");
        ResponseJson.Add('quantity', TrackingSpecification."Quantity (Base)");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
