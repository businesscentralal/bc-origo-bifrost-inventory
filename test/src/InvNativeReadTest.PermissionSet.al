namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Assembly.History;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;

/// <summary>Test-only native read rights; grants neither posting token nor licensed dispatch.</summary>
permissionset 96965 "Inv Native Read Test"
{
    Assignable = true;
    Caption = 'Inventory native read test', MaxLength = 30;
    IncludedPermissionSets = "Inv Cost Read Test";
    Permissions =
        table "Item Journal Line" = X,
        tabledata "Item Journal Line" = R,
        table "Transfer Shipment Header" = X,
        tabledata "Transfer Shipment Header" = R,
        table "Transfer Receipt Header" = X,
        tabledata "Transfer Receipt Header" = R,
        table "Posted Assembly Header" = X,
        tabledata "Posted Assembly Header" = R,
        table "Item Application Entry" = X,
        tabledata "Item Application Entry" = R;
}
