namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Close. Closes an inventory period through the Inventory Period record.
/// </summary>
codeunit 70013485 "Period Close Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Closes inventory periods through an ending date, matching the inventory period close action.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('close inventory period, lock inventory period');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Closes an inventory period. An already closed period returns success.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Period.Close');
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
        Response.Add('closed', true);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Get', 'Read inventory periods before closing one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Reopen', 'Reopen a closed inventory period instead of closing it.'));
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
        Overview := 'Closes an inventory period. An already closed period returns success.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Sets Inventory Period.Closed. It does not post inventory.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
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
        MissingDateErr: Label 'endingDate is required.', Comment = 'is-IS=endingDate er nauðsynlegt.';
        NotFoundErr: Label 'Inventory period ending %1 was not found.', Comment = '%1 = ending date||is-IS=Birgðatímabil sem lýkur %1 fannst ekki.';
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
        if not InventoryPeriod.Closed then begin
            InventoryPeriod.Validate(Closed, true);
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
