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
        EnableItemCategoryDomain();
    end;

    local procedure EnableItemCategoryDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
        InventoryInstall: Codeunit "Inventory Install ori";
    begin
        if UpgradeTag.HasUpgradeTag(InventoryInstall.GetItemCategoryDomainTag()) then
            exit;
        if InventorySetup.FindSet(true) then
            repeat
                InventorySetup.Validate("Item Category", true);
                InventorySetup.Modify(true);
            until InventorySetup.Next() = 0;
        UpgradeTag.SetUpgradeTag(InventoryInstall.GetItemCategoryDomainTag());
    end;
}
