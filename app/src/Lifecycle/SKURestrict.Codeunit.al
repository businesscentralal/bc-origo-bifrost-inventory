namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Location;
using Origo.Bifrost;

/// <summary>
/// Refuses generic Data.Records.Set against stockkeeping units and names the dedicated types in the refusal.
/// Callers use Inventory.SKU.Create and Inventory.SKU.Get. Reads stay allowed.
/// </summary>
codeunit 10076999 "SKU Restrict ori"
{
    Access = Internal;

    var
        SKUWriteHintTxt: Label 'Inventory.SKU.Create / Inventory.SKU.Get', Locked = true;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictStockkeepingUnit(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo = Database::"Stockkeeping Unit" then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintStockkeepingUnitWrite(TableNo: Integer; var Hint: Text)
    begin
        if Hint <> '' then
            exit;
        if TableNo = Database::"Stockkeeping Unit" then
            Hint := SKUWriteHintTxt;
    end;
}
