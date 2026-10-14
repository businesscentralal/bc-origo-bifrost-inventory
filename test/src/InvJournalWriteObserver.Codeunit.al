namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;

/// <summary>Owned test subscriber proves rollback after an actual protected ledger insertion.</summary>
codeunit 96961 "Inv Journal Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        ItemNo: Code[20];
        CountMode: Boolean;
        ApplicationEntryNo: Integer;
        ApplicationOutboundNo: Integer;
        FailureLbl: Label 'Owned native journal insert failure', Locked = true;

    /// <summary>Restricts failure injection to the self-created test item.</summary>
    procedure SetItem(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
        CountMode := false;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure FailAfterInsert(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if not CountMode and not Rec.IsTemporary() and (Rec."Item No." = ItemNo) then
            Error(FailureLbl);
    end;
    /// <summary>Fails after an actual physical-count Modify on the owned item.</summary>
    procedure SetCountItem(NewItemNo: Code[20])
    begin
        ItemNo := NewItemNo;
        CountMode := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterModifyEvent', '', false, false)]
    local procedure FailAfterCount(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line"; RunTrigger: Boolean)
    begin
        if CountMode and not Rec.IsTemporary() and (Rec."Item No." = ItemNo) and Rec."Phys. Inventory" then
            Error(FailureLbl);
    end;
    /// <summary>Fails after a native unapply deletes the selected self-created application.</summary>
    procedure SetApplication(EntryNo: Integer)
    begin
        ApplicationEntryNo := EntryNo;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Application Entry", 'OnAfterDeleteEvent', '', false, false)]
    local procedure FailAfterUnapply(var Rec: Record "Item Application Entry"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (ApplicationEntryNo <> 0) and (Rec."Entry No." = ApplicationEntryNo) then
            Error(FailureLbl);
    end;
    /// <summary>Fails after native reapply inserts an application for the self-created outbound entry.</summary>
    procedure SetApplicationOutbound(EntryNo: Integer)
    begin
        ApplicationOutboundNo := EntryNo;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Application Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure FailAfterReapply(var Rec: Record "Item Application Entry"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (ApplicationOutboundNo <> 0) and (Rec."Outbound Item Entry No." = ApplicationOutboundNo) then
            Error(FailureLbl);
    end;
}
