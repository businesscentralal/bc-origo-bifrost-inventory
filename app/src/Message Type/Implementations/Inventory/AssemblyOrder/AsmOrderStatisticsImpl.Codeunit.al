namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.Statistics message type.
/// Returns header information, line counts, quantities and cost breakdown
/// (material, resource, capacity, overhead) for an assembly order.
/// Mirrors page 901 "Assembly Order Statistics" by calling CalcActualCosts.
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013422 "Asm. Order Statistics Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.ReadPermission());
    end;
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Returns assembly order statistics: header info, line counts, quantities and cost breakdown.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assembly statistics, assembly cost, cost of components, kit cost breakdown', Comment = 'is-IS=tölfræði samsetningar, kostnaður samsetningar, kostnaður íhluta, sundurliðun kostnaðar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads assembly quantities, line counts and cost breakdown without changing the order; use PreviewPost for posting prediction.', Comment = 'is-IS=Les magn, línufjölda og kostnaðarsundurgreiningu samsetningar án breytinga; notaðu PreviewPost til að spá fyrir um bókun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Target := Parts.GetTarget('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin exit(false); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Response := Parts.GetResponse('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Errors := Parts.GetErrors('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Effect := Parts.GetEffect('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Related := Parts.GetRelated('Inventory.AssemblyOrder.Statistics'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Overview := Parts.GetOverview('Inventory.AssemblyOrder.Statistics'); exit(Overview <> ''); end;
    procedure GetNotes(var Notes: Text): Boolean begin exit(false); end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        ResponseJson: JsonObject;
        CostsJson: JsonObject;
        LinesJson: JsonObject;
        ActualCost: array[5] of Decimal;
        ItemLineCount: Integer;
        ResourceLineCount: Integer;
        TextLineCount: Integer;
        TotalLineCount: Integer;
        TotalCostExpected: Decimal;
        TotalCostActual: Decimal;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        // Count lines by type
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        TotalLineCount := AssemblyLine.Count();

        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        ItemLineCount := AssemblyLine.Count();
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Resource);
        ResourceLineCount := AssemblyLine.Count();
        AssemblyLine.SetRange(Type, AssemblyLine.Type::" ");
        TextLineCount := AssemblyLine.Count();
        AssemblyLine.SetRange(Type);

        // Calculate actual costs (indexed 1..5: Material, Resource, Capacity, CapacityOverhead, MfgOverhead)
        AssemblyHeader.CalcActualCosts(ActualCost);
        TotalCostActual := ActualCost[1] + ActualCost[2] + ActualCost[3] + ActualCost[4] + ActualCost[5];

        // Expected cost is summed from assembly lines (Page 920 pattern).
        AssemblyLine.CalcSums("Cost Amount");
        TotalCostExpected := AssemblyLine."Cost Amount";

        CostsJson.Add('totalExpectedCost', TotalCostExpected);
        CostsJson.Add('totalActualCost', TotalCostActual);
        CostsJson.Add('actualMaterialCost', ActualCost[1]);
        CostsJson.Add('actualResourceCost', ActualCost[2]);
        CostsJson.Add('actualCapacityCost', ActualCost[3]);
        CostsJson.Add('actualCapacityOverhead', ActualCost[4]);
        CostsJson.Add('actualMfgOverhead', ActualCost[5]);
        CostsJson.Add('unitCost', AssemblyHeader."Unit Cost");
        CostsJson.Add('indirectCostPercent', AssemblyHeader."Indirect Cost %");
        CostsJson.Add('overheadRate', AssemblyHeader."Overhead Rate");

        LinesJson.Add('total', TotalLineCount);
        LinesJson.Add('item', ItemLineCount);
        LinesJson.Add('resource', ResourceLineCount);
        LinesJson.Add('text', TextLineCount);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('systemId', Format(AssemblyHeader.SystemId, 0, 4));
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('variantCode', AssemblyHeader."Variant Code");
        ResponseJson.Add('description', AssemblyHeader.Description);
        ResponseJson.Add('locationCode', AssemblyHeader."Location Code");
        ResponseJson.Add('unitOfMeasureCode', AssemblyHeader."Unit of Measure Code");
        ResponseJson.Add('quantity', AssemblyHeader.Quantity);
        ResponseJson.Add('quantityToAssemble', AssemblyHeader."Quantity to Assemble");
        ResponseJson.Add('assembledQuantity', AssemblyHeader."Assembled Quantity");
        ResponseJson.Add('remainingQuantity', AssemblyHeader."Remaining Quantity");
        ResponseJson.Add('reservedQuantity', AssemblyHeader."Reserved Quantity");
        ResponseJson.Add('assembleToOrder', AssemblyHeader."Assemble to Order");
        ResponseJson.Add('status_', StatusToText(AssemblyHeader.Status));
        ResponseJson.Add('postingDate', Format(AssemblyHeader."Posting Date", 0, 9));
        ResponseJson.Add('dueDate', Format(AssemblyHeader."Due Date", 0, 9));
        ResponseJson.Add('startingDate', Format(AssemblyHeader."Starting Date", 0, 9));
        ResponseJson.Add('endingDate', Format(AssemblyHeader."Ending Date", 0, 9));
        ResponseJson.Add('lines', LinesJson);
        ResponseJson.Add('costs', CostsJson);

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure StatusToText(StatusValue: Option Open,Released): Text
    begin
        case StatusValue of
            StatusValue::Open:
                exit('Open');
            StatusValue::Released:
                exit('Released');
        end;
        exit('');
    end;
}
