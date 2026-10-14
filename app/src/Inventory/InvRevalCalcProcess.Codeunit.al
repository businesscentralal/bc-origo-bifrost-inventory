namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Isolates native revaluation calculation in the shipping transaction.</summary>
codeunit 70013401 "Inv Reval Calc Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Revaluation: Codeunit "Inventory Revaluation ori";
    begin
        Revaluation.Calculate(Rec);
    end;
}
