namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against item charge assignment tables and points the caller to
/// Inventory.ItemCharge.Assign and Inventory.ItemCharge.Get. Reads stay allowed.
/// </summary>
codeunit 10036921 "Item Charge Restrict ori"
{
    Access = Internal;

    var
        WriteHintTok: Label 'Inventory.ItemCharge.Assign / Inventory.ItemCharge.Get', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictItemChargeAssignment(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsAssignmentTable(TableNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintItemChargeAssignment(TableNo: Integer; var Hint: Text)
    begin
        if IsAssignmentTable(TableNo) then
            Hint := WriteHintTok;
    end;

    local procedure IsAssignmentTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Item Charge Assignment (Purch)", Database::"Item Charge Assignment (Sales)"]);
    end;
}
