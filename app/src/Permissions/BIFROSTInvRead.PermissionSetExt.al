namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;
using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Extends Foundation <c>BIFROST Read ori</c> with execute rights for Item.Attribute.Get and helpers.
/// </summary>
permissionsetextension 10036915 "BIFROST InvRead ori" extends "BIFROST Read ori"
{
    Permissions =
        tabledata "Item Attribute" = R,
        tabledata "Item Attribute Value" = R,
        tabledata "Item Attribute Value Mapping" = R,
        tabledata "Item Attr. Value Translation" = R,
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
        codeunit "Inventory Source Resolve ori" = X,
        codeunit "Inventory Tracking Read ori" = X,
        codeunit "Tracking Get Impl ori" = X,
        codeunit "Tracking Avail. Get Impl ori" = X,
        codeunit "Reservation Get Impl ori" = X,
        codeunit "Inventory Domain Gate ori" = X,
        codeunit "Inv. Posting Gate ori" = X,
        codeunit "Inventory Cost Reports ori" = X,
        codeunit "Cost To GL Test Impl ori" = X,
        codeunit "Inventory Cost Read ori" = X,
        codeunit "Cost Get Impl ori" = X;
}
