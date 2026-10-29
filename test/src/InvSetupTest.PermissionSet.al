namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.Environment.Configuration;

/// <summary>Supplies Setup-page access at the supported Foundation floor and the platform baseline; grants no Inventory subscriber Execute or administration.</summary>
permissionset 96972 "Inv Setup Test"
{
    Assignable = true;
    Caption = 'Inventory Setup Platform Test', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    // Foundation 28.0.3.530 lacks the Setup-page Execute now included in LicAdm.
    // Grant only the page under test, never the Inventory registration subscriber.
    Permissions =
        page "Setup ori" = X,
        tabledata "NAV App Setting" = r;
}
