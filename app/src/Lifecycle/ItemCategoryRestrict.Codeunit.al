namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against item categories and their attribute mappings, and names the
/// dedicated types in the refusal. Callers use Inventory.ItemCategory.Get and Inventory.ItemCategory.Set.
/// Reads stay allowed.
/// </summary>
codeunit 10076847 "Item Category Restrict ori"
{
    Access = Internal;

    var
        ItemCategoryWriteHintTxt: Label 'Inventory.ItemCategory.Get / Inventory.ItemCategory.Set', Locked = true;
        MappingWriteHintTxt: Label 'Inventory.Attribute.Create / Inventory.Attribute.Update / Inventory.ItemCategory.Set', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictItemCategory(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Item Category", Database::"Item Attribute Value Mapping"] then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintItemCategoryWrite(TableNo: Integer; var Hint: Text)
    begin
        if Hint <> '' then
            exit;
        case TableNo of
            Database::"Item Category":
                Hint := ItemCategoryWriteHintTxt;
            Database::"Item Attribute Value Mapping":
                Hint := MappingWriteHintTxt;
        end;
    end;
}
