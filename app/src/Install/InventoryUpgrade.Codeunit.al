namespace Origo.Bifrost.Inventory;

using System.Upgrade;

/// <summary>
/// Upgrade entry point for Bifrost Inventory. Ensures the initial-release tag is present.
/// </summary>
codeunit 10036910 "Inventory Upgrade ori"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
        InventoryInstall: Codeunit "Inventory Install ori";
    begin
        if not UpgradeTag.HasUpgradeTag(InventoryInstall.GetInitialReleaseTag()) then
            UpgradeTag.SetUpgradeTag(InventoryInstall.GetInitialReleaseTag());
    end;
}
