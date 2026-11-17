namespace Origo.Bifrost.Inventory;

using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>Undoes selected posted sales shipment lines through Undo Sales Shipment Line.</summary>
codeunit 10077028 "Sales Undo Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Undo: Codeunit "Posted Line Undo ori";
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DescriptionLbl: Label 'Undoes selected posted sales shipment lines with native corrective entries.', Comment = 'is-IS=Afturkallar valdar línur í bókaðri söluafhendingu með innbyggðum leiðréttingarfærslum.';
        KeywordsLbl: Label 'undo posted sales shipment reverse lines', Comment = 'is-IS=afturkalla bókaða söluafhendingu leiðrétta línur';

    /// <summary>Supplies the IsEnabled contract for Sales.Shipment.Undo.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(Undo.IsEnabled(Database::"Sales Shipment Header"));
    end;

    /// <summary>Supplies the GetFilterTableNo contract for Sales.Shipment.Undo.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Shipment Header");
    end;

    /// <summary>Supplies the GetDescription contract for Sales.Shipment.Undo.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies the GetKeywords contract for Sales.Shipment.Undo.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Supplies the GetSelectionDescription contract for Sales.Shipment.Undo.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies the GetEnvelope contract for Sales.Shipment.Undo.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(Undo.GetEnvelope(Envelope));
    end;

    /// <summary>Supplies the GetTarget contract for Sales.Shipment.Undo.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(Undo.GetTarget(Target));
    end;

    /// <summary>Supplies the GetParameters contract for Sales.Shipment.Undo.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(Undo.GetParameters(Parameters));
    end;

    /// <summary>Supplies the GetResponse contract for Sales.Shipment.Undo.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(Undo.GetResponse(Response));
    end;

    /// <summary>Supplies the GetErrors contract for Sales.Shipment.Undo.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(Undo.GetErrors(Errors));
    end;

    /// <summary>Supplies the GetEffect contract for Sales.Shipment.Undo.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(Undo.GetEffect(Effect));
    end;

    /// <summary>Supplies the GetMetering contract for Sales.Shipment.Undo.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the GetRelated contract for Sales.Shipment.Undo.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        RelatedLbl: Label 'Use purchase receipt undo when correcting goods received from a vendor.', Comment = 'is-IS=Notaðu afturköllun innkaupamóttöku þegar leiðrétta á vörur mótteknar frá lánardrottni.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Purchase.Receipt.Undo', RelatedLbl));
        exit(true);
    end;

    /// <summary>Supplies the GetWorkflow contract for Sales.Shipment.Undo.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Sales.Shipment.Undo', DescriptionLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Supplies the GetExamples contract for Sales.Shipment.Undo.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Examples.Add(ContractMgt.Example(DescriptionLbl, '{"type":"Sales.Shipment.Undo","data":{"documentNo":"POSTED-001","lineNos":[10000],"expectedCount":1}}', '{"status":"Success","documentNo":"POSTED-001","reversedLineNos":[10000],"reversedCount":1}'));
        exit(true);
    end;

    /// <summary>Supplies the GetOverview contract for Sales.Shipment.Undo.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := DescriptionLbl;
        exit(true);
    end;

    /// <summary>Supplies the GetNotes contract for Sales.Shipment.Undo.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(Undo.GetNotes(Notes));
    end;

    /// <summary>Supplies the GetMessageDirection contract for Sales.Shipment.Undo.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Supplies the ExecuteBifrostTask contract for Sales.Shipment.Undo.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Undo.Execute(Argument, true);
    end;
}
