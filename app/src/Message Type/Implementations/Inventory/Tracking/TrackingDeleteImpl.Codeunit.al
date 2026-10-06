namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.Tracking.Delete. Removes an unposted tracking specification.
/// </summary>
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
        exit('Deletes an unposted item tracking specification.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('delete lot, delete serial, delete package');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Deletes an unposted tracking specification. Posted item ledger entries are not deleted.');
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
        EntryNo: Integer;
        MissingEntryErr: Label 'entryNo is required.', Locked = true;
        NotFoundErr: Label 'Tracking specification %1 was not found. Posted item ledger entries cannot be deleted here.', Comment = '%1 = entry no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingEntryErr, 'entryNo', '', '', '');
            exit;
        end;
        EntryNo := Token.AsValue().AsInteger();
        if not TrackingSpecification.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EntryNo), 'entryNo', '', '', '');
            exit;
        end;
        TrackingSpecification.Delete(true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', TrackingSpecification."Item No.");
        ResponseJson.Add('serialNo', TrackingSpecification."Serial No.");
        ResponseJson.Add('lotNo', TrackingSpecification."Lot No.");
        ResponseJson.Add('packageNo', TrackingSpecification."Package No.");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
