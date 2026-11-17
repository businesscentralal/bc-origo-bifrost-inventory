namespace Origo.Bifrost.Inventory;

using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;

/// <summary>Inventory.StandardCost.Implement: native standard cost worksheet operation.</summary>
codeunit 10076933 "Std. Cost Implement Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Std. Cost Contract ori";
        Management: Codeunit "Std. Cost Management ori";

    /// <summary>Provides the IsEnabled operation for standard cost implement.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(Management.IsEnabled(true));
    end;

    /// <summary>Provides the GetFilterTableNo operation for standard cost implement.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Standard Cost Worksheet");
    end;

    /// <summary>Provides the GetDescription operation for standard cost implement.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(CopyStr(Contract.Description(true), 1, 250));
    end;

    /// <summary>Provides the GetKeywords operation for standard cost implement.</summary>
    procedure GetKeywords(): Text
    begin
        exit(Contract.Keywords());
    end;

    /// <summary>Provides the GetSelectionDescription operation for standard cost implement.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(Contract.Description(true));
    end;

    /// <summary>Provides the GetEnvelope operation for standard cost implement.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(Contract.GetEnvelope(Envelope, true));
    end;

    /// <summary>Provides the GetTarget operation for standard cost implement.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(Contract.GetTarget(Target, true));
    end;

    /// <summary>Provides the GetParameters operation for standard cost implement.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(Contract.GetParameters(Parameters, true));
    end;

    /// <summary>Provides the GetResponse operation for standard cost implement.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(Contract.GetResponse(Response, true));
    end;

    /// <summary>Provides the GetErrors operation for standard cost implement.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(Contract.GetErrors(Errors, true));
    end;

    /// <summary>Provides the GetEffect operation for standard cost implement.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(Contract.GetEffect(Effect, true));
    end;

    /// <summary>Provides the GetRelated operation for standard cost implement.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(Contract.GetRelated(Related, true));
    end;

    /// <summary>Provides the GetExamples operation for standard cost implement.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(Contract.GetExamples(Examples, true));
    end;

    /// <summary>Provides the GetOverview operation for standard cost implement.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        exit(Contract.GetOverview(Overview, true));
    end;

    /// <summary>Provides the GetNotes operation for standard cost implement.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(Contract.GetNotes(Notes, true));
    end;

    /// <summary>Provides the GetMetering operation for standard cost implement.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    /// <summary>Provides the GetWorkflow operation for standard cost implement.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(Contract.GetWorkflow(Workflow, true));
    end;

    /// <summary>Provides the GetMessageDirection operation for standard cost implement.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Provides the ExecuteBifrostTask operation for standard cost implement.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Management.ExecuteImplement(Argument);
    end;
}
