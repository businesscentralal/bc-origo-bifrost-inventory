namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Origo.Bifrost;

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
        exit('Closes open inventory periods through the requested ending date.');
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
        ClosedPeriods: JsonArray;
        PeriodJson: JsonObject;
        Token: JsonToken;
        EndingDate: Date;
        ClosedCount: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::InventoryPeriod, Database::"Inventory Period", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('endingDate', Token) then begin
            Argument.RespondWithError('endingDate is required.');
            exit;
        end;
        if not Evaluate(EndingDate, Token.AsValue().AsText()) then begin
            Argument.RespondWithError('endingDate is not a date.');
            exit;
        end;

        InventoryPeriod.SetFilter("Ending Date", '..%1', EndingDate);
        InventoryPeriod.SetRange(Closed, false);
        if InventoryPeriod.FindSet(true) then
            repeat
                InventoryPeriod.Closed := true;
                InventoryPeriod.Modify(true);
                Clear(PeriodJson);
                PeriodJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
                PeriodJson.Add('name', InventoryPeriod.Name);
                PeriodJson.Add('closed', InventoryPeriod.Closed);
                ClosedPeriods.Add(PeriodJson);
                ClosedCount += 1;
            until InventoryPeriod.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('endingDate', Format(EndingDate, 0, 9));
        ResponseJson.Add('closedCount', ClosedCount);
        ResponseJson.Add('periods', ClosedPeriods);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
