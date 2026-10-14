namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Native Item read access for restricted costing callers; product execution comes from the shipping roles.</summary>
permissionset 96934 "Inv Cost Read Test"
{
    Assignable = true;
    Caption = 'Inventory cost read test', MaxLength = 30;
    Permissions =
        table Item = X,
        tabledata Item = R,
        table "Inventory Setup ori" = X,
        table "Inv. Posting ori" = X,
        tabledata "Message Argument ori" = RIMD;
}
