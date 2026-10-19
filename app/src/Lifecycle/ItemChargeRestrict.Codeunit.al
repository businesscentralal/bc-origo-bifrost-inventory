namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against item charge assignment tables.
/// Callers use Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get. Reads stay allowed.
/// </summary>
codeunit 10036921 "Item Charge Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictItemChargeAssignment(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Item Charge Assignment (Purch)", Database::"Item Charge Assignment (Sales)"] then
            IsRestricted := true;
    end;
}
