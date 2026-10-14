namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Ledger;

/// <summary>Owned test subscriber proves rollback after an actual protected ledger insertion.</summary>
codeunit 96961 "Inv Journal Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        ItemNo: Code[20];
        FailureLbl: Label 'Owned native journal insert failure', Locked = true;

    /// <summary>Restricts failure injection to the self-created test item.</summary>
    procedure SetItem(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure FailAfterInsert(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (Rec."Item No." = ItemNo) then
            Error(FailureLbl);
    end;
}
