namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Sales.Document;

/// <summary>Test-only source read grant, deliberately excluding write access and all reservation tabledata rights.</summary>
permissionset 96930 "Inv Source Read Test"
{
    Assignable = true;
    Caption = 'Inventory source read test', MaxLength = 30;

    IncludedPermissionSets = "Inv Source Deny Test";
    Permissions = tabledata "Sales Line" = R;
}
