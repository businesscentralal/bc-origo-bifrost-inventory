namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Runs an item charge assignment in its own write so a failure rolls back and returns a clean error.
/// </summary>
codeunit 70013499 "Item Charge Runner ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ItemChargeAssign: Codeunit "Item Charge Assign Impl ori";
    begin
        ItemChargeAssign.RunAssign(Rec);
    end;
}
