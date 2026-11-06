namespace Origo.Bifrost.Inventory;

using System.Upgrade;

/// <summary>
/// Upgrade entry point for Bifrost Inventory. Applies tagged per-company domain defaults from inventory usage.
/// </summary>
codeunit 10076836 "Inventory Upgrade ori"
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
        EnableUsedDomains();
    end;

    /// <summary>Runs the usage migration once per company and preserves absent setup rows.</summary>
    internal procedure EnableUsedDomains()
    var
        InventorySetup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetDomainUsageTag()) then
            exit;
        InventorySetup.ReadIsolation := IsolationLevel::UpdLock;
        if InventorySetup.Get() then
            if InventorySetup.EnableDomainsInUse() then
                InventorySetup.Modify(true);
        UpgradeTag.SetUpgradeTag(GetDomainUsageTag());
    end;

    /// <summary>Identifies the one-time company usage migration.</summary>
    internal procedure GetDomainUsageTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-DomainUsage-20261023');
    end;
}
