namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.Environment.Configuration;
using System.Security.AccessControl;
using System.TestLibraries.Security.AccessControl;

/// <summary>Supplies the Foundation Setup-open baseline while excluding Inventory registration Execute.</summary>
permissionset 96972 "Inv Setup Test"
{
    Assignable = true;
    Caption = 'Inventory Setup Platform Test', Locked = true;
    // All Objects is Microsoft's execute-only test baseline, without tabledata writes.
    // Foundation 530 lacks several internal Setup Execute grants even in Read.
    // Subtract the subscriber Execute granted by Inventory's Read extension so
    // opening Setup still proves the subscriber's inherent Execute properties.
    IncludedPermissionSets = "D365 Basic - Read", "Guided Experience - View", "BIFROST Read ori", "All Objects";
    ExcludedPermissionSets = "Inv Reg Excl Test";
    Permissions = tabledata "NAV App Setting" = r;
}
