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
        codeunit "Item Attribute Get Impl ori" = X,
        codeunit "Item Attribute Get Help ori" = X,
        codeunit "Item Attribute Resolve ori" = X,
        codeunit "Item Attr. Data Restrict ori" = X,
        codeunit "Inventory Registration ori" = X,
        codeunit "Inventory Install ori" = X,
        codeunit "Inventory Upgrade ori" = X,
        codeunit "Transfer Order Stats Impl ori" = X,
        codeunit "Transfer Order Stats Help ori" = X,
        codeunit "Asm. Order Statistics Impl ori" = X,
        codeunit "Asm. Order Statistics Help ori" = X;
}
