namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Runs native adjustment behind a codeunit-run failure boundary; report commits remain native.</summary>
codeunit 70013461 "Adjust Cost Run Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        CostReports: Codeunit "Inventory Cost Reports ori";
        Response: JsonObject;
    begin
        CostReports.AdjustCost(Rec.GetRequestJson(), Response);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>Runs the native report and preserves a structured failure without promising rollback of native commits.</summary>
    procedure RunAdjustCost(var Argument: Record "Message Argument ori")
    begin
        if not Codeunit.Run(Codeunit::"Adjust Cost Run Process ori", Argument) then
            Argument.RespondWithError(GetLastErrorText());
    end;
}
