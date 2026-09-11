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
        codeunit "Item Attribute Data Restrict ori" = X,
        codeunit "Inventory Registration ori" = X,
        codeunit "Inventory Install ori" = X,
        codeunit "Inventory Upgrade ori" = X;
}
