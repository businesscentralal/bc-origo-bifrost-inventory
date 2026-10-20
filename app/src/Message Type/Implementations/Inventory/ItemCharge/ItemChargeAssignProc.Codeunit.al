namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.ItemCharge.Assign. Validation has already refused bad requests; an error raised by
/// Business Central here rolls the whole assignment back and is answered as a clean error by the caller.
/// </summary>
codeunit 10076874 "Item Charge Assign Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        AssignImpl: Codeunit "Item Charge Assign Impl ori";
    begin
        AssignImpl.RunAssign(Rec);
    end;
}
