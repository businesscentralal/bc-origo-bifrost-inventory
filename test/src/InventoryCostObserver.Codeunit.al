namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;

/// <summary>Observes real report 795 options without changing report behavior.</summary>
codeunit 96932 "Inventory Cost Observer"
{
    EventSubscriberInstance = Manual;

    var
        ObservedFilter: Text;
        ObservedItemByItem: Boolean;

    /// <summary>Returns the filter received by the native report.</summary>
    procedure ItemFilter(): Text
    begin
        exit(ObservedFilter);
    end;

    /// <summary>Returns the native item-by-item commit parameter.</summary>
    procedure ItemByItem(): Boolean
    begin
        exit(ObservedItemByItem);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnBeforePreReport, '', false, false)]
    local procedure ObserveRequest(ItemNoFilter: Text[250]; ItemCategoryFilter: Text[250]; PostToGL: Boolean; var Item: Record Item)
    begin
        ObservedFilter := ItemNoFilter;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnAfterSetCostAdjustmentParameter, '', false, false)]
    local procedure ObserveParameters(var CostAdjustmentParameter: Record "Cost Adjustment Parameter")
    begin
        ObservedItemByItem := CostAdjustmentParameter."Item-By-Item Commit";
    end;
}
