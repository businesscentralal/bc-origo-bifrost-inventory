namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;

/// <summary>Supplies the native item-by-item parameter for one bound report 795 execution.</summary>
codeunit 70013431 "Inventory Cost Options ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        ItemByItem: Boolean;
        ProcessedItems: List of [Code[20]];
        ReportCompleted: Boolean;

    /// <summary>Sets the native commit option without changing company setup.</summary>
    procedure SetItemByItem(Value: Boolean)
    begin
        ItemByItem := Value;
    end;

    /// <summary>Counts distinct items whose native adjustment completed during this bound invocation.</summary>
    procedure ItemsProcessed(): Integer
    begin
        exit(ProcessedItems.Count());
    end;

    /// <summary>Distinguishes a completed report from the native early exit when no ledger exists.</summary>
    procedure Completed(): Boolean
    begin
        exit(ReportCompleted);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Inventory Adjustment", OnAfterAdjustItem, '', false, false)]
    local procedure ObserveAdjustedItem(var TheItem: Record Item)
    begin
        if not ProcessedItems.Contains(TheItem."No.") then
            ProcessedItems.Add(TheItem."No.");
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnAfterPreReport, '', false, false)]
    local procedure ObserveReportCompletion()
    begin
        ReportCompleted := true;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnAfterSetCostAdjustmentParameter, '', false, false)]
    local procedure ApplyNativeOption(var CostAdjustmentParameter: Record "Cost Adjustment Parameter")
    begin
        CostAdjustmentParameter."Item-By-Item Commit" := ItemByItem;
    end;
}
