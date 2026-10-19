namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;

/// <summary>Fails after a physical-count modification to prove the native transaction rolls back.</summary>
codeunit 96961 "Inv Journal Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        ItemNo: Code[20];
        FailureLbl: Label 'Owned native journal insert failure', Locked = true;

    /// <summary>Restricts failure injection to the self-created physical-count item.</summary>
    procedure SetCountItem(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterModifyEvent', '', false, false)]
    local procedure FailAfterCount(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (Rec."Item No." = ItemNo) and Rec."Phys. Inventory" then
            Error(FailureLbl);
    end;
}
