namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;

/// <summary>Supplies the native item-by-item parameter for one bound report 795 execution.</summary>
codeunit 70013431 "Inventory Cost Options ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        ItemByItem: Boolean;

    /// <summary>Sets the native commit option without changing company setup.</summary>
    procedure SetItemByItem(Value: Boolean)
    begin
        ItemByItem := Value;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnAfterSetCostAdjustmentParameter, '', false, false)]
    local procedure ApplyNativeOption(var CostAdjustmentParameter: Record "Cost Adjustment Parameter")
    begin
        CostAdjustmentParameter."Item-By-Item Commit" := ItemByItem;
    end;
}
