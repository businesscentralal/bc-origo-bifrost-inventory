namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;

/// <summary>Native journal read access only, exercising the shipping reclassification Check implementation.</summary>
permissionset 96971 "Inv Reclass Read"
{
    Assignable = true;
    Caption = 'Reclassification read test', MaxLength = 30;
    Permissions =
        table "Item Journal Template" = X,
        tabledata "Item Journal Template" = R,
        table "Item Journal Line" = X,
        tabledata "Item Journal Line" = R,
        table "Inventory Setup ori" = X,
        table "Inv. Posting ori" = X,
        tabledata "Message Argument ori" = RIMD;
}
