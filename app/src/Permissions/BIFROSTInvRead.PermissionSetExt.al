namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Foundation <c>BIFROST Read ori</c> with execute rights for the read-only Inventory message types and helpers.
/// Standard-table data for the item reference, availability, item charge, item category and order
/// tracking types comes from the caller's own Business Central permissions; IsEnabled and Execute check it.
/// </summary>
permissionsetextension 10076835 "BIFROST InvRead ori" extends "BIFROST Read ori"
{
    IncludedPermissionSets = "BIFROST InvAttrRead ori";

    Permissions =
        tabledata "Inventory Setup ori" = R,
        codeunit "Cost To GL Test Impl ori" = X,
        codeunit "Item Appl. Get Impl ori" = X,
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
        codeunit "Inventory Tracking Read ori" = X,
        codeunit "Tracking Get Impl ori" = X,
        codeunit "Tracking Avail. Get Impl ori" = X,
        codeunit "Inventory Domain Gate ori" = X,
        codeunit "Inventory Native Journal ori" = X,
        codeunit "Phys. Inv. Check Impl ori" = X,
        codeunit "Phys. Inv. Preview Impl ori" = X,
        codeunit "Inv. Posting Gate ori" = X,
        codeunit "Item Ref. Resolve Impl ori" = X,
        codeunit "Avail. By Period Impl ori" = X,
        codeunit "Item Charge Get Impl ori" = X,
        codeunit "Item Charge Restrict ori" = X,
        codeunit "Item Category Get Impl ori" = X,
        codeunit "Item Category Restrict ori" = X,
        codeunit "Order Tracking Get Impl ori" = X,
        codeunit "Order Tracking Transfer ori" = X;
}
