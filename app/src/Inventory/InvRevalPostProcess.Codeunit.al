namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Isolates native revaluation posting in the shipping transaction.</summary>
codeunit 70013402 "Inv Reval Post Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Revaluation: Codeunit "Inventory Revaluation ori";
    begin
        Revaluation.Post(Rec);
    end;
}
