namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.Environment.Configuration;

/// <summary>Supplies the Foundation Setup-open baseline while excluding Inventory registration Execute.</summary>
permissionset 96972 "Inv Setup Test"
{
    Assignable = true;
    Caption = 'Inventory Setup Platform Test', Locked = true;
    // Foundation 530's internal Setup dependencies must come from its own role.
    // Subtract the subscriber Execute granted by Inventory's Read extension so
    // opening Setup still proves the subscriber's inherent Execute properties.
    IncludedPermissionSets = "Guided Experience - View", "BIFROST Read ori";
    ExcludedPermissionSets = "Inv Reg Excl Test";
    Permissions = tabledata "NAV App Setting" = r;
}
