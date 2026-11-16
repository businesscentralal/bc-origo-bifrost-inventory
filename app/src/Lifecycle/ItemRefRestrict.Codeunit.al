namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Catalog;
using Origo.Bifrost;

/// <summary>Directs generic item reference writes to the validated dedicated type.</summary>
codeunit 10076932 "Item Ref. Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictWrites(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Item Reference" then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintWrite(TableNo: Integer; var Hint: Text)
    begin
        if (TableNo = Database::"Item Reference") and (Hint = '') then
            Hint := 'Inventory.ItemReference.Set';
    end;
}
