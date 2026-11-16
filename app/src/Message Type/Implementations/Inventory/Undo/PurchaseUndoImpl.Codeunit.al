namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.History;
using Origo.Bifrost;

/// <summary>Undoes selected posted purchase receipt lines through Undo Purchase Receipt Line.</summary>
codeunit 10077026 "Purchase Undo Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Undo: Codeunit "Posted Line Undo ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DescriptionLbl: Label 'Undoes selected posted purchase receipt lines with native corrective entries.', Comment = 'is-IS=Afturkallar valdar línur í bókaðri innkaupamóttöku með innbyggðum leiðréttingarfærslum.';
        KeywordsLbl: Label 'undo posted purchase receipt reverse lines', Comment = 'is-IS=afturkalla bókaða innkaupamóttöku leiðrétta línur';

    /// <summary>Supplies the IsEnabled contract for Purchase.Receipt.Undo.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(Undo.IsEnabled(Database::"Purch. Rcpt. Header"));
    end;

    /// <summary>Supplies the GetFilterTableNo contract for Purchase.Receipt.Undo.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Purch. Rcpt. Header");
    end;

    /// <summary>Supplies the GetDescription contract for Purchase.Receipt.Undo.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies the GetKeywords contract for Purchase.Receipt.Undo.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Supplies the GetSelectionDescription contract for Purchase.Receipt.Undo.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies the GetEnvelope contract for Purchase.Receipt.Undo.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(Undo.GetEnvelope(Envelope));
    end;

    /// <summary>Supplies the GetTarget contract for Purchase.Receipt.Undo.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(Undo.GetTarget(Target));
    end;

    /// <summary>Supplies the GetParameters contract for Purchase.Receipt.Undo.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(Undo.GetParameters(Parameters));
    end;

    /// <summary>Supplies the GetResponse contract for Purchase.Receipt.Undo.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(Undo.GetResponse(Response));
    end;

    /// <summary>Supplies the GetErrors contract for Purchase.Receipt.Undo.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(Undo.GetErrors(Errors));
    end;

    /// <summary>Supplies the GetEffect contract for Purchase.Receipt.Undo.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(Undo.GetEffect(Effect));
    end;

    /// <summary>Supplies the GetMetering contract for Purchase.Receipt.Undo.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the GetRelated contract for Purchase.Receipt.Undo.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add(ContractMgt.RelatedEntry('Sales.Shipment.Undo', DescriptionLbl));
        exit(true);
    end;

    /// <summary>Supplies the GetWorkflow contract for Purchase.Receipt.Undo.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Purchase.Receipt.Undo', DescriptionLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Supplies the GetExamples contract for Purchase.Receipt.Undo.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Examples.Add(ContractMgt.Example(DescriptionLbl, '{"type":"Purchase.Receipt.Undo","data":{"documentNo":"POSTED-001","lineNos":[10000],"expectedCount":1}}', '{"status":"Success","documentNo":"POSTED-001","reversedLineNos":[10000],"reversedCount":1}'));
        exit(true);
    end;

    /// <summary>Supplies the GetOverview contract for Purchase.Receipt.Undo.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := DescriptionLbl;
        exit(true);
    end;

    /// <summary>Supplies the GetNotes contract for Purchase.Receipt.Undo.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(Undo.GetNotes(Notes));
    end;

    /// <summary>Supplies the GetMessageDirection contract for Purchase.Receipt.Undo.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Supplies the ExecuteBifrostTask contract for Purchase.Receipt.Undo.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Undo.Execute(Argument, false);
    end;
}
