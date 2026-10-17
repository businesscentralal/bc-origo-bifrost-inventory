namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against item categories and their attribute mappings.
/// Callers use Inventory.ItemCategory.Get and Inventory.ItemCategory.Set. Reads stay allowed.
/// </summary>
codeunit 70013441 "Item Category Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictItemCategory(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Item Category", Database::"Item Attribute Value Mapping"] then
            IsRestricted := true;
    end;
}
