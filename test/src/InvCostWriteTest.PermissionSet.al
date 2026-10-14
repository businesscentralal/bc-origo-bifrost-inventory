namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;

/// <summary>Native Item write access without a posting token or product execution grants.</summary>
permissionset 96935 "Inv Cost Write Test"
{
    Assignable = true;
    Caption = 'Inventory cost write test', MaxLength = 30;
    IncludedPermissionSets = "Inv Cost Read Test";
    Permissions = tabledata Item = RIMD;
}
