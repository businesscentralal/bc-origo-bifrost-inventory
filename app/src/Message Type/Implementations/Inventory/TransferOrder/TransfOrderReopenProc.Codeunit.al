namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;

/// <summary>
/// Isolates the call to Release Transfer Document.Reopen so it runs outside the
/// outer ProcessIncomingMessage TryFunction context (LockTable is not allowed inside
/// a TryFunction, but is allowed inside a Codeunit.Run).
/// </summary>
codeunit 70013418 "Transf. Order Reopen Proc. ori"
{
    Access = Internal;
    TableNo = "Transfer Header";

    trigger OnRun()
    var
        ReleaseTransferDoc: Codeunit "Release Transfer Document";
    begin
        ReleaseTransferDoc.Reopen(Rec);
    end;
}
