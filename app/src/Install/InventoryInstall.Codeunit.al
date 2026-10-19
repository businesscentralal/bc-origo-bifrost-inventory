namespace Origo.Bifrost.Inventory;

using System.Upgrade;

/// <summary>
/// Fresh install entry point for Bifrost Inventory. Sets the initial-release upgrade tag.
/// </summary>
codeunit 10036909 "Inventory Install ori"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    begin
        SetUpgradeTags();
        InsertSetup();
    end;

    local procedure InsertSetup()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        InventorySetup.InsertIfNotExists();
    end;

    local procedure SetUpgradeTags()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag(GetInitialReleaseTag()) then
            UpgradeTag.SetUpgradeTag(GetInitialReleaseTag());
    end;

    procedure GetInitialReleaseTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-Initial-20260911');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetInitialReleaseTag());
    end;
}
