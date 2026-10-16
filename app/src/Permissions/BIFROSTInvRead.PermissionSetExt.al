namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Foundation <c>BIFROST Read ori</c> with execute rights for Item.Attribute.Get and helpers.
/// </summary>
permissionsetextension 10036915 "BIFROST InvRead ori" extends "BIFROST Read ori"
{
    IncludedPermissionSets = "BIFROST InvAttrRead ori";

    Permissions =
        tabledata "Inventory Setup ori" = R,
        codeunit "Item Attribute Get Impl ori" = X,
        codeunit "Item Attribute Resolve ori" = X,
        codeunit "Item Attr. Data Restrict ori" = X,
        codeunit "Inventory Registration ori" = X,
        codeunit "Inventory Install ori" = X,
        codeunit "Inventory Upgrade ori" = X,
        codeunit "Transfer Order Stats Impl ori" = X,
        codeunit "Asm. Order Statistics Impl ori" = X,
        codeunit "Inventory Contract Parts ori" = X,
        codeunit "Inventory Cost Read ori" = X,
        codeunit "Inventory Cost Data Guard ori" = X,
        codeunit "Cost Get Impl ori" = X,
        codeunit "Inventory Source Resolve ori" = X,
        codeunit "Inventory Tracking Read ori" = X,
        codeunit "Tracking Get Impl ori" = X,
        codeunit "Tracking Avail. Get Impl ori" = X,
        codeunit "Inventory Domain Gate ori" = X,
        codeunit "Inventory Native Journal ori" = X,
        codeunit "Phys. Inv. Check Impl ori" = X,
        codeunit "Phys. Inv. Preview Impl ori" = X,
        codeunit "Inv. Posting Gate ori" = X;
}
