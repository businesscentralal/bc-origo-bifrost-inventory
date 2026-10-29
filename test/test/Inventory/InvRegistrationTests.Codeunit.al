namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Exercises Inventory registration when a restricted licence administrator opens Foundation setup.</summary>
codeunit 96972 "Inv. Registration Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    /// <summary>AC02: Setup opens without granting the licence administrator general Bifrost administration.</summary>
    [Test]
    procedure AC02_LicAdm_OpensSetupWithInventoryInstalled()
    var
        BifrostSetup: Record "Setup ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SetupPage: TestPage "Setup ori";
    begin
        // Story #173 AC02 | Time: independent | Risk: an event subscriber requires extra Execute grants.
        BifrostSetup.InsertIfNotExists();

        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        LowerPermissions.AddPermissionSet('Inv Setup Test');
        Assert.IsFalse(BifrostSetup.WritePermission(), 'Licence administration must not grant direct Setup writes.');

        SetupPage.OpenView();
        Assert.IsFalse(SetupPage.Editable(), 'A licence administrator must not become a Bifrost administrator.');
        Assert.IsTrue(SetupPage.RefreshLicense.Visible(), 'The licence-administrator action remains available.');
        SetupPage.Close();
    end;
}
