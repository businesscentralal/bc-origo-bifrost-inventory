namespace Origo.Bifrost.Inventory;

using Microsoft.Pricing.PriceList;
using Origo.Bifrost;

/// <summary>Price.List.Set: governed native price-list maintenance.</summary>
codeunit 10076980 "Price List Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Price List Contract ori";

    /// <summary>Checks domain and native permissions.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(Contract.IsEnabled());
    end;

    /// <summary>Identifies the native target table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Price List Header");
    end;

    /// <summary>Declares inbound maintenance.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Executes the licensed operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Contract.Configure(false);
        Contract.Execute(Argument);
    end;

    /// <summary>Returns localized price-list discovery.</summary>
    procedure GetDescription(): Text[250]
    begin
        Contract.Configure(false);
        exit(Contract.GetDescription());
    end;

    /// <summary>Returns localized price-list discovery.</summary>
    procedure GetKeywords() : Text
    begin
        Contract.Configure(false);
        exit(Contract.GetKeywords());
    end;

    /// <summary>Returns localized price-list discovery.</summary>
    procedure GetSelectionDescription() : Text
    begin
        Contract.Configure(false);
        exit(Contract.GetSelectionDescription());
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetEnvelope(Envelope));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetTarget(Target));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetParameters(Parameters));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetResponse(Response));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetErrors(Errors));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetEffect(Effect));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetRelated(Related));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetWorkflow(Workflow));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetExamples(Examples));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetOverview(Overview));
    end;

    /// <summary>Returns the Set contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.Configure(false);
        exit(Contract.GetNotes(Notes));
    end;

    /// <summary>Uses Foundation metering defaults.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
}
