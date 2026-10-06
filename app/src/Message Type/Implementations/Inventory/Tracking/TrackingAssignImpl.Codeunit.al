namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

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
        exit('Assigns lot, serial, or package tracking through Item Tracking Management.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('assign lot, assign serial, assign package, item tracking');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Assigns item tracking through codeunit 6500.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Tracking.Assign');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Item Tracking Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'quantity');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lotNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'serialNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'packageNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('entryNo', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'itemNo, quantity, or a tracking number is missing');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Tracking Specification');
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
        Overview := 'Creates a tracking specification and registers it through Item Tracking Management.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Calls codeunit 6500 Item Tracking Management. Package number is included.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TrackingSpecification: Record "Tracking Specification";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        LotNo: Code[50];
        SerialNo: Code[50];
        PackageNo: Code[50];
        Quantity: Decimal;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError('itemNo is required.');
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ItemNo));
        if not RequestJson.Get('quantity', Token) then begin
            Argument.RespondWithError('quantity is required.');
            exit;
        end;
        Quantity := Token.AsValue().AsDecimal();
        if RequestJson.Get('lotNo', Token) then
            LotNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(LotNo));
        if RequestJson.Get('serialNo', Token) then
            SerialNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(SerialNo));
        if RequestJson.Get('packageNo', Token) then
            PackageNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(PackageNo));
        if (LotNo = '') and (SerialNo = '') and (PackageNo = '') then begin
            Argument.RespondWithError('lotNo, serialNo, or packageNo is required.');
            exit;
        end;

        TrackingSpecification.Init();
        TrackingSpecification."Item No." := ItemNo;
        TrackingSpecification."Lot No." := LotNo;
        TrackingSpecification."Serial No." := SerialNo;
        TrackingSpecification."Package No." := PackageNo;
        TrackingSpecification."Quantity (Base)" := Quantity;
        TrackingSpecification.Insert(true);
        ItemTrackingManagement.SetPointerFilter(TrackingSpecification);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', TrackingSpecification."Entry No.");
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('lotNo', LotNo);
        ResponseJson.Add('serialNo', SerialNo);
        ResponseJson.Add('packageNo', PackageNo);
        ResponseJson.Add('quantity', Quantity);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
