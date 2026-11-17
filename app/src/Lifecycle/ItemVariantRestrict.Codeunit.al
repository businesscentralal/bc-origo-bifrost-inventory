namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against item variants and names the dedicated types in the refusal.
/// Callers use Inventory.ItemVariant.Get and Inventory.ItemVariant.Create. Reads stay allowed.
/// </summary>
codeunit 10076993 "Item Variant Restrict ori"
{
    Access = Internal;

    var
        ItemVariantWriteHintTxt: Label 'Inventory.ItemVariant.Get / Inventory.ItemVariant.Create', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictItemVariant(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Item Variant" then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintItemVariantWrite(TableNo: Integer; var Hint: Text)
    begin
        if Hint <> '' then
            exit;
        if TableNo = Database::"Item Variant" then
            Hint := ItemVariantWriteHintTxt;
    end;
}
