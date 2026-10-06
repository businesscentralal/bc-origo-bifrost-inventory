namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013471 "Tracking Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Deletes an item tracking specification through Item Tracking Management.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('delete tracking, delete lot, delete serial, delete package');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Deletes one tracking specification by entry number.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Tracking.Delete');
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
        ParameterJson.Add('name', 'entryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', true);
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
        ErrorJson.Add('when', 'entryNo was not found');
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
        Related.Add('Inventory.Tracking.Assign');
        Related.Add('Inventory.TrackingAvailability.Get');
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
        Overview := 'Deletes one tracking specification after registering the pointer with Item Tracking Management.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Calls codeunit 6500 before delete. Package number is returned when present.';
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
        EntryNo: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError('entryNo is required.');
            exit;
        end;
        EntryNo := Token.AsValue().AsInteger();
        if not TrackingSpecification.Get(EntryNo) then begin
            Argument.RespondWithError('Tracking specification ' + Format(EntryNo) + ' was not found.');
            exit;
        end;

        ItemTrackingManagement.SetPointerFilter(TrackingSpecification);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', TrackingSpecification."Item No.");
        ResponseJson.Add('lotNo', TrackingSpecification."Lot No.");
        ResponseJson.Add('serialNo', TrackingSpecification."Serial No.");
        ResponseJson.Add('packageNo', TrackingSpecification."Package No.");
        TrackingSpecification.Delete(true);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
