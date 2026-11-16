namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Sales.ReturnOrder.CreateFromPosted. Validation has already refused bad requests; an error raised
/// by Business Central here rolls the new header and every copied line back and is answered as a clean error by the caller.
/// </summary>
codeunit 10077033 "Sales Ret. Ord. Post. Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        CreateImpl: Codeunit "Sales Ret. Ord. Post. Impl ori";
    begin
        CreateImpl.RunCreateFromPosted(Rec);
    end;
}
