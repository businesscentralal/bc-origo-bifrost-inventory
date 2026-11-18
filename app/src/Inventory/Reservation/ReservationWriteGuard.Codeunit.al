namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Blocks generic reservation writes and directs callers to the native reservation message types.</summary>
codeunit 10076843 "Reservation WriteGuard ori"
{
    Access = Internal;

    var
        WriteHintTok: Label 'Inventory.Reservation.Create / Inventory.Reservation.Cancel', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictReservationEntry(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Reservation Entry" then
            IsRestricted := true;
    end;
    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintReservationWrite(TableNo: Integer; var Hint: Text)
    begin
        if (TableNo = Database::"Reservation Entry") and (Hint = '') then
            Hint := WriteHintTok;
    end;

}
