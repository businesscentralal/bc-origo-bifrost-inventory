namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

/// <summary>Holds a real native insert transaction briefly so another real session must contend with it.</summary>
codeunit 96992 "Inv Contention Observer"
{
    EventSubscriberInstance = Manual;

    var
        OwnedItemNo: Code[20];
        OwnedOutbound: Integer;
        HoldStarted: DateTime;
        HoldFinished: DateTime;

    /// <summary>Restricts observation to this invocation's own fixture.</summary>
    procedure SetFixture(ItemNo: Code[20]; Outbound: Integer)
    begin
        OwnedItemNo := ItemNo;
        OwnedOutbound := Outbound;
    end;

    /// <summary>Returns measured event timestamps, not assumed concurrency.</summary>
    procedure GetTiming(var Started: DateTime; var Finished: DateTime)
    begin
        Started := HoldStarted;
        Finished := HoldFinished;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure ReservationInserted(var Rec: Record "Reservation Entry"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (OwnedOutbound = 0) and (Rec."Item No." = OwnedItemNo) then
            HoldNativeTransaction();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Application Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure ApplicationInserted(var Rec: Record "Item Application Entry"; RunTrigger: Boolean)
    begin
        if not Rec.IsTemporary() and (OwnedOutbound <> 0) and (Rec."Outbound Item Entry No." = OwnedOutbound) then
            HoldNativeTransaction();
    end;

    local procedure HoldNativeTransaction()
    begin
        if HoldStarted <> 0DT then
            exit;
        HoldStarted := CurrentDateTime();
        Sleep(3000);
        HoldFinished := CurrentDateTime();
    end;
}
