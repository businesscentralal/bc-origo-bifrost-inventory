namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Reopen. Reopens a closed inventory period.
/// </summary>
codeunit 70013484 "Period Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Inventory Period");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Reopens a closed inventory period.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('reopen inventory period');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reopens a closed inventory period.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Period.Reopen');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Inventory Period');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'endingDate');
        ParameterJson.Add('type', 'date');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('endingDate', '');
        Response.Add('name', '');
        Response.Add('closed', false);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'endingDate is required.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'RecordNotFound');
        ErrorJson.Add('when', 'the inventory period was not found.');
        Errors.Add(ErrorJson);
        exit(true);
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Get', 'Read inventory periods before reopening one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Close', 'Close an inventory period instead of reopening it.'));
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
        Overview := 'Reopens a closed inventory period.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Clears Inventory Period.Closed. It does not post inventory.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        InventoryPeriod: Record "Inventory Period";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EndingDate: Date;
        MissingDateErr: Label 'endingDate is required.', Locked = true;
        NotFoundErr: Label 'Inventory period ending %1 was not found.', Comment = '%1 = ending date', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('endingDate', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingDateErr, 'endingDate', '', '', '');
            exit;
        end;
        EndingDate := Token.AsValue().AsDate();
        if not InventoryPeriod.Get(EndingDate) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EndingDate), 'endingDate', '', '', '');
            exit;
        end;
        if InventoryPeriod.Closed then begin
            InventoryPeriod.Validate(Closed, false);
            InventoryPeriod.Modify(true);
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson.Add('name', InventoryPeriod.Name);
        ResponseJson.Add('closed', InventoryPeriod.Closed);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
