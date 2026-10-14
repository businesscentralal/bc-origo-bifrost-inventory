namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;

/// <summary>Native journal write rights only; no Foundation or Inventory posting token is granted.</summary>
permissionset 96963 "Inv Jnl Write Test"
{
    Assignable = true;
    Caption = 'Inventory journal write test', MaxLength = 30;
    IncludedPermissionSets = "Inv Cost Read Test";
    Permissions =
        table "Item Journal Line" = X,
        tabledata "Item Journal Line" = RIMD;
}
