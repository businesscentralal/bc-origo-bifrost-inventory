namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013498 "Reservation WriteGuard ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictReservationEntry(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Reservation Entry" then
            IsRestricted := true;
    end;
}
