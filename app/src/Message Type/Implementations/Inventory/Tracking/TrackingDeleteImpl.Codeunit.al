namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013471 "Tracking Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Inventory Setup ori", false, false) and Resolver.HasTrackingWritePermission());
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
        Clear(Parameters);
        ParameterJson.Add('name', 'source');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', 'Source type and systemId; transfers also accept transferDirection (Outbound or Inbound).');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'entryNos');
        ParameterJson.Add('type', 'array');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Reservation entry numbers belonging to this source. Omit to remove all source tracking; an empty array changes nothing.');
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('entriesDeleted', 0);
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
        Effect.Add('writes', 'Source tracking through native tracking and reservation APIs');
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking instead of deleting it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read tracking availability before deleting a specification.'));
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
        Overview := 'Removes tracking only from the specified source through native tracking and reservation APIs.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Entry numbers are validated against the source before any change. Native reservation pairing and source validation remain active.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Inventory Setup ori", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingWrite.SetDeleteMode();
        if Argument."Omit Commit" then
            TrackingWrite.Run(Argument)
        else
            if not TrackingWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
