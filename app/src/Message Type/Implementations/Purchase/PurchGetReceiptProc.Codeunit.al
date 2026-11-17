namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Isolated write for Purchase.PurchaseInvoice.GetReceiptLines. Validation has already refused bad requests; an error raised
/// by Business Central here rolls every added invoice line back and is answered as a clean error by the caller.
/// </summary>
codeunit 10077031 "Purch Get Receipt Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        GetReceiptImpl: Codeunit "Purch Get Receipt Impl ori";
    begin
        GetReceiptImpl.RunGetReceiptLines(Rec);
    end;
}
