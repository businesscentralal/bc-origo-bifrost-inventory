namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

/// <summary>Observes real report 795 options without changing report behavior.</summary>
codeunit 96932 "Inventory Cost Observer"
{
    EventSubscriberInstance = Manual;

    var
        ObservedFilter: Text;
        ObservedItemByItem: Boolean;
        ObservedPostToGL: Boolean;
        ObservedReport1002Runs: Integer;

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

    /// <summary>Returns the native adjustment G/L option.</summary>
    procedure PostToGLOption(): Boolean
    begin
        exit(ObservedPostToGL);
    end;

    /// <summary>Counts actual report 1002 invocations without altering their behavior.</summary>
    procedure Report1002Runs(): Integer
    begin
        exit(ObservedReport1002Runs);
    end;

    [EventSubscriber(ObjectType::Report, Report::"Post Inventory Cost to G/L", OnBeforePreReport, '', false, false)]
    local procedure ObserveGLReport(var Item: Record Item; var ItemValueEntry: Record "Value Entry"; var PostValueEntryToGL: Record "Post Value Entry to G/L"; Post: Boolean)
    begin
        ObservedReport1002Runs += 1;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnBeforePreReport, '', false, false)]
    local procedure ObserveRequest(ItemNoFilter: Text[250]; ItemCategoryFilter: Text[250]; PostToGL: Boolean; var Item: Record Item)
    begin
        ObservedFilter := ItemNoFilter;
        ObservedPostToGL := PostToGL;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Adjust Cost - Item Entries", OnAfterSetCostAdjustmentParameter, '', false, false)]
    local procedure ObserveParameters(var CostAdjustmentParameter: Record "Cost Adjustment Parameter")
    begin
        ObservedItemByItem := CostAdjustmentParameter."Item-By-Item Commit";
    end;
}
