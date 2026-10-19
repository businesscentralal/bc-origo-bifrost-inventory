namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Isolates intentional card-cost changes so a native validation failure cannot leave a partial write.</summary>
codeunit 70013434 "Inventory Cost Write Proc. ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        CostWrite: Codeunit "Inventory Cost Write ori";
    begin
        CostWrite.UpdateCost(Rec);
    end;
}
