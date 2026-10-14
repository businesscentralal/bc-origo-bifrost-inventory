namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.History;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;

/// <summary>Test-only native write rights; grants neither posting token nor licensed dispatch.</summary>
permissionset 96966 "Inv Native Wrt Test"
{
    Assignable = true;
    Caption = 'Inventory native write test', MaxLength = 30;
    IncludedPermissionSets = "Inv Cost Read Test";
    Permissions =
        table "Item Journal Line" = X,
        tabledata "Item Journal Line" = RIMD,
        table "Transfer Shipment Header" = X,
        tabledata "Transfer Shipment Header" = RIMD,
        table "Transfer Receipt Header" = X,
        tabledata "Transfer Receipt Header" = RIMD,
        table "Posted Assembly Header" = X,
        tabledata "Posted Assembly Header" = RIMD,
        table "Item Application Entry" = X,
        tabledata "Item Application Entry" = RIMD;
}
