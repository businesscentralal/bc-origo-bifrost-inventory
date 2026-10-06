namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Origo.Bifrost;

/// <summary>
/// Inventory.Period.Reopen. Reopens a closed inventory period through the standard Closed validation.
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
        DomainGate: Codeunit "Inventory Domain Gate ori";
        InventoryPeriod: Record "Inventory Period";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EndingDate: Date;
        MissingEndingDateErr: Label 'endingDate is required.', Locked = true;
        InvalidEndingDateErr: Label 'endingDate must be an XML date.', Locked = true;
        PeriodNotFoundErr: Label 'Inventory period %1 was not found.', Comment = '%1 = ending date', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('endingDate', Token) then begin
            Argument.RespondWithError(MissingEndingDateErr);
            exit;
        end;
        if not Evaluate(EndingDate, Token.AsValue().AsText(), 9) then begin
            Argument.RespondWithError(InvalidEndingDateErr);
            exit;
        end;
        if not InventoryPeriod.Get(EndingDate) then begin
            Argument.RespondWithError(StrSubstNo(PeriodNotFoundErr, EndingDate));
            exit;
        end;

        if InventoryPeriod.Closed then begin
            InventoryPeriod.Validate(Closed, false);
            InventoryPeriod.Modify(true);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.Period.Reopen');
        ResponseJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson.Add('name', InventoryPeriod.Name);
        ResponseJson.Add('closed', InventoryPeriod.Closed);
        Argument.SetResponseJson(ResponseJson);
    end;
}
