namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Native Item and costing ledger read access for restricted costing callers; product execution comes from the shipping roles.</summary>
permissionset 96934 "Inv Cost Read Test"
{
    Assignable = true;
    Caption = 'Inventory cost read test', MaxLength = 30;
    Permissions =
        table Item = X,
        tabledata Item = R,
        table "Item Ledger Entry" = X,
        tabledata "Item Ledger Entry" = R,
        table "Value Entry" = X,
        tabledata "Value Entry" = R,
        table "Inventory Setup ori" = X,
        table "Inv. Posting ori" = X,
        tabledata "Message Argument ori" = RIMD;
}
