namespace Origo.Bifrost.Inventory;

using Microsoft.Manufacturing.StandardCost;
using Origo.Bifrost;

/// <summary>Inventory.StandardCost.Suggest: native standard cost worksheet operation.</summary>
codeunit 10076938 "Std. Cost Suggest Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Std. Cost Contract ori";
        Management: Codeunit "Std. Cost Management ori";

    /// <summary>Provides the IsEnabled operation for standard cost suggest.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(Management.IsEnabled(false));
    end;

    /// <summary>Provides the GetFilterTableNo operation for standard cost suggest.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Standard Cost Worksheet");
    end;

    /// <summary>Provides the GetDescription operation for standard cost suggest.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(CopyStr(Contract.Description(false), 1, 250));
    end;

    /// <summary>Provides the GetKeywords operation for standard cost suggest.</summary>
    procedure GetKeywords(): Text
    begin
        exit(Contract.Keywords());
    end;

    /// <summary>Provides the GetSelectionDescription operation for standard cost suggest.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(Contract.Description(false));
    end;

    /// <summary>Provides the GetEnvelope operation for standard cost suggest.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(Contract.GetEnvelope(Envelope, false));
    end;

    /// <summary>Provides the GetTarget operation for standard cost suggest.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(Contract.GetTarget(Target, false));
    end;

    /// <summary>Provides the GetParameters operation for standard cost suggest.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(Contract.GetParameters(Parameters, false));
    end;

    /// <summary>Provides the GetResponse operation for standard cost suggest.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(Contract.GetResponse(Response, false));
    end;

    /// <summary>Provides the GetErrors operation for standard cost suggest.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(Contract.GetErrors(Errors, false));
    end;

    /// <summary>Provides the GetEffect operation for standard cost suggest.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(Contract.GetEffect(Effect, false));
    end;

    /// <summary>Provides the GetRelated operation for standard cost suggest.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(Contract.GetRelated(Related, false));
    end;

    /// <summary>Provides the GetExamples operation for standard cost suggest.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(Contract.GetExamples(Examples, false));
    end;

    /// <summary>Provides the GetOverview operation for standard cost suggest.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        exit(Contract.GetOverview(Overview, false));
    end;

    /// <summary>Provides the GetNotes operation for standard cost suggest.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(Contract.GetNotes(Notes, false));
    end;

    /// <summary>Provides the GetMetering operation for standard cost suggest.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    /// <summary>Provides the GetWorkflow operation for standard cost suggest.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(Contract.GetWorkflow(Workflow, false));
    end;

    /// <summary>Provides the GetMessageDirection operation for standard cost suggest.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Provides the ExecuteBifrostTask operation for standard cost suggest.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Management.ExecuteSuggest(Argument);
    end;
}
