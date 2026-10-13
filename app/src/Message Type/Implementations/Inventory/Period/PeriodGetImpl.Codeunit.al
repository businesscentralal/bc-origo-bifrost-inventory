namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Get. Reads inventory periods.
/// </summary>
codeunit 70013483 "Period Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Inventory Period");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Reads inventory periods.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('inventory period, closed period');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reads inventory periods. Close and reopen are separate types.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Period.Get');
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
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('periods', 'array');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Close', 'Close an inventory period instead of only reading it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Period.Reopen', 'Reopen a closed inventory period instead of only reading it.'));
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
        Overview := 'Reads inventory periods.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Close and reopen are separate message types.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        InventoryPeriod: Record "Inventory Period";
        ResponseJson: JsonObject;
        Periods: JsonArray;
        PeriodJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if InventoryPeriod.FindSet() then
            repeat
                Clear(PeriodJson);
                PeriodJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
                PeriodJson.Add('name', InventoryPeriod.Name);
                PeriodJson.Add('closed', InventoryPeriod.Closed);
                Periods.Add(PeriodJson);
            until InventoryPeriod.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('periods', Periods);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
