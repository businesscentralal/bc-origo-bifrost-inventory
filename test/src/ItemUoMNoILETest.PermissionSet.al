namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>
/// Reads items and item units of measure but not item ledger entries, for the Item UoM permission regression test.
/// </summary>
permissionset 96921 "Item UoM No ILE Test"
{
    Caption = 'Item UoM No ILE Test', MaxLength = 30;
    Assignable = true;

    Permissions =
        tabledata "Message Argument ori" = RIMD,
        tabledata Item = R,
        tabledata "Item Unit of Measure" = R,
        tabledata "Inventory Setup ori" = R,
        codeunit "Item UoM Get Impl ori" = X;
}
