namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Checks that the Bifröst page links Inventory Setup in its Related menu.</summary>
codeunit 97903 "Bifrost Related Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    [HandlerFunctions('InventorySetupHandler')]
    procedure BifrostPage_InventorySetupAction_OpensSetupPage()
    var
        Bifrost: TestPage "Bifrost ori";
    begin
        Bifrost.OpenView();
        Assert.IsTrue(Bifrost.BifrostInventorySetup.Visible(), 'Inventory Setup action must be visible on the Bifröst page.');
        Assert.IsTrue(Bifrost.BifrostInventorySetup.Enabled(), 'Inventory Setup action must be enabled.');
        Bifrost.BifrostInventorySetup.Invoke();
        Bifrost.Close();
    end;

    [PageHandler]
    procedure InventorySetupHandler(var SetupPage: TestPage "Inventory Setup ori")
    begin
        Assert.IsTrue(SetupPage.Attributes.Visible(), 'The Inventory Setup page must open from the Bifröst page.');
    end;
}
