namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.Environment.Configuration;

/// <summary>Supplies the Setup-open page, registry and notification dependencies at the supported Foundation floor and the platform baseline; grants no Inventory subscriber Execute or administration.</summary>
permissionset 96972 "Inv Setup Test"
{
    Assignable = true;
    Caption = 'Inventory Setup Platform Test', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    // Foundation 28.0.3.530 predates the inherent Execute on the Setup-open path.
    // Grant only these Foundation dependencies, never any Inventory codeunit.
    Permissions =
        page "Setup ori" = X,
        codeunit "App Registry ori" = X,
        table "Registered App ori" = X,
        tabledata "NAV App Setting" = r;
}
