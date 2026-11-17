namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Manufacturing.StandardCost;

/// <summary>Injects a native standard-cost failure after an earlier worksheet item was updated.</summary>
codeunit 96983 "Std. Cost Failure Test ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        FailItemNo: Code[20];

    /// <summary>Names the second item whose native update must fail.</summary>
    procedure SetFailItem(ItemNo: Code[20])
    begin
        FailItemNo := ItemNo;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Implement Standard Cost Change", OnBeforeUpdateItem, '', false, false)]
    local procedure FailSelectedItem(var StandardCostWorksheet: Record "Standard Cost Worksheet"; PostingDate: Date)
    var
        InjectedErr: Label 'Owned standard-cost rollback test failure.', Locked = true;
    begin
        if StandardCostWorksheet."No." = FailItemNo then
            Error(InjectedErr);
    end;
}
