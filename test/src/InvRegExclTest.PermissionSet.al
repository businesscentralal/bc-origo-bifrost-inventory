namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost.Inventory;

/// <summary>Removes the registration subscriber's Execute grant from the restricted Setup test baseline.</summary>
permissionset 96973 "Inv Reg Excl Test"
{
    Assignable = false;
    Caption = 'Inventory Registration Exclusion Test', Locked = true;
    Permissions = codeunit "Inventory Registration ori" = X;
}
