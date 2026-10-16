namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Ledger;

/// <summary>Injects an error after the native revaluation value entry was inserted for one owned item.</summary>
codeunit 96942 "Inv Revaluation Observer"
{
    EventSubscriberInstance = Manual;

    var
        TargetItemNo: Code[20];

    /// <summary>Scopes failure injection to the test-owned item.</summary>
    procedure SetItem(ItemNo: Code[20])
    begin
        TargetItemNo := ItemNo;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Value Entry", OnAfterInsertEvent, '', false, false)]
    local procedure AfterInsertValue(var Rec: Record "Value Entry"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if (Rec."Item No." = TargetItemNo) and (Rec."Entry Type" = Rec."Entry Type"::Revaluation) then
            Error('Owned revaluation failure after native value entry insertion.');
    end;
}
