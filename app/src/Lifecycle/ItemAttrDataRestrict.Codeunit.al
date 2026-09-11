namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Refuses generic <c>Data.Records.Set</c> against Item Attribute tables so callers use the
/// dedicated <c>Item.Attribute.*</c> message types. Reads via <c>Data.Records.Get</c> stay allowed.
/// </summary>
codeunit 10036911 "Item Attr. Data Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", 'OnAfterIsTableWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictAttributeTablesFromWrite(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if IsAttributeTable(TableNo) then
            IsRestricted := true;
    end;

    local procedure IsAttributeTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [
            Database::"Item Attribute",
            Database::"Item Attribute Value",
            Database::"Item Attr. Value Translation",
            Database::"Item Attribute Value Mapping"]);
    end;
}
