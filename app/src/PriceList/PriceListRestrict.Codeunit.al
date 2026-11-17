namespace Origo.Bifrost.Inventory;

using Microsoft.Pricing.PriceList;
using Origo.Bifrost;

/// <summary>Routes generic price-list writes through validated maintenance and activation.</summary>
codeunit 10076984 "Price List Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsTableWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictPriceLists(TableNo: Integer; var IsRestricted: Boolean)
    begin
        if TableNo in [Database::"Price List Header", Database::"Price List Line"] then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForWrite, '', false, false)]
    local procedure HintPriceLists(TableNo: Integer; var Hint: Text)
    begin
        if TableNo in [Database::"Price List Header", Database::"Price List Line"] then
            Hint := 'Price.List.Set / Price.List.Activate';
    end;
}
