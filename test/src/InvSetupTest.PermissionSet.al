namespace Origo.Bifrost.Inventory.Test;

using System.Environment.Configuration;

/// <summary>Supplies only the platform baseline for Setup; does not grant Inventory subscriber Execute or administration.</summary>
permissionset 96972 "Inv Setup Test"
{
    Assignable = true;
    Caption = 'Inventory Setup Platform Test', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    Permissions = tabledata "NAV App Setting" = r;
}
