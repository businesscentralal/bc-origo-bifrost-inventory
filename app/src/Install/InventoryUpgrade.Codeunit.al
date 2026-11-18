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
        EnableUsedCatalogItems();
        EnablePlanningDomain();
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

    /// <summary>
    /// Runs once per company: turns the Catalog Items domain (added after the first usage migration) on when the
    /// company has catalog items. Other switches are not touched and absent setup rows stay absent.
    /// </summary>
    internal procedure EnableUsedCatalogItems()
    var
        InventorySetup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetCatalogItemsUsageTag()) then
            exit;
        InventorySetup.ReadIsolation := IsolationLevel::UpdLock;
        if InventorySetup.Get() then
            if InventorySetup.EnableCatalogItemsInUse() then
                InventorySetup.Modify(true);
        UpgradeTag.SetUpgradeTag(GetCatalogItemsUsageTag());
    end;

    /// <summary>Identifies the one-time Catalog Items usage migration.</summary>
    internal procedure GetCatalogItemsUsageTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-CatalogItemsUsage-20261116');
    end;

    /// <summary>Turns on Planning once when a planning worksheet template exists. Other domain switches are not changed.</summary>
    internal procedure EnablePlanningDomain()
    var
        InventorySetup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetPlanningDomainTag()) then
            exit;
        InventorySetup.ReadIsolation := IsolationLevel::UpdLock;
        if InventorySetup.Get() then
            if InventorySetup.EnablePlanningFromUsage() then
                InventorySetup.Modify(true);
        UpgradeTag.SetUpgradeTag(GetPlanningDomainTag());
    end;

    /// <summary>Identifies the one-time company usage migration.</summary>
    internal procedure GetDomainUsageTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-DomainUsage-20261023');
    end;

    /// <summary>Identifies the one-time Planning switch for companies that already have a planning worksheet template.</summary>
    internal procedure GetPlanningDomainTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-PlanningDomain-20261117');
    end;
}
