namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013544 "Tracking Data Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictTrackingTables(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Tracking Specification", Database::"Reservation Entry"] then
            IsRestricted := true;
    end;
}
