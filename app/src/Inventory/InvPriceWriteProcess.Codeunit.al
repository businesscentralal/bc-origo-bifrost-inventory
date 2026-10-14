namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Rolls back native price validation and subscriber changes when a write fails.</summary>
codeunit 70013439 "Inv. Price Write Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        PriceWrite: Codeunit "Inventory Price Write ori";
    begin
        PriceWrite.UpdatePrice(Rec);
    end;
}
