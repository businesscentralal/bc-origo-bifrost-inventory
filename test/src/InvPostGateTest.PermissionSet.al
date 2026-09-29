namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>
/// Document and argument permissions for the inventory posting-gate tests.
/// Does not grant Inv. Posting ori. BIFROST InvPost ori is added only on the grant path.
/// </summary>
permissionset 96920 "Inv Post Gate Test"
{
    Caption = 'Inv Post Gate Test', MaxLength = 30;
    Assignable = true;

    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata "Transfer Header" = RIMD,
        tabledata "Assembly Header" = RIMD,
        codeunit "Inv. Posting Gate ori" = X,
        codeunit "Transfer Order Post Impl ori" = X,
        codeunit "Assembly Order Post Impl ori" = X,
        codeunit "Transf Doc Prev. Post Impl ori" = X,
        codeunit "Asm. Doc Prev. Post Impl ori" = X;
}
