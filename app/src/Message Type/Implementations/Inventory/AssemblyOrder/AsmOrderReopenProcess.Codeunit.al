namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;

/// <summary>
/// Internal helper codeunit used by Assembly Order Reopen Impl.
/// Wraps codeunit 414 Release Assembly Document.Reopen in a separate transaction
/// so the outer impl can capture errors without rolling itself back.
/// </summary>
codeunit 70013428 "Asm. Order Reopen Process ori"
{
    Access = Internal;
    TableNo = "Assembly Header";

    trigger OnRun()
    var
        ReleaseAssemblyDoc: Codeunit "Release Assembly Document";
    begin
        ReleaseAssemblyDoc.Reopen(Rec);
    end;
}
