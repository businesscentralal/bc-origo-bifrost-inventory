namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;
using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Extends Foundation <c>BIFROST Full ori</c> with write access for Item Attribute message types.
/// </summary>
permissionsetextension 10036916 "BIFROST InvWrite ori" extends "BIFROST Full ori"
{
    Permissions =
        tabledata "Item Attribute" = RIMD,
        tabledata "Item Attribute Value" = RIMD,
        tabledata "Item Attribute Value Mapping" = RIMD,
        tabledata "Item Attr. Value Translation" = RIMD,
        codeunit "Item Attribute Get Impl ori" = X,
        codeunit "Item Attribute Get Help ori" = X,
        codeunit "Item Attribute Create Impl ori" = X,
        codeunit "Item Attribute Create Help ori" = X,
        codeunit "Item Attribute Create Process ori" = X,
        codeunit "Item Attribute Update Impl ori" = X,
        codeunit "Item Attribute Update Help ori" = X,
        codeunit "Item Attribute Update Process ori" = X,
        codeunit "Item AttributeDefinition Create Impl ori" = X,
        codeunit "Item AttributeDefinition Create Help ori" = X,
        codeunit "Item AttributeDefinition Create Process ori" = X,
        codeunit "Item Attribute Resolve ori" = X,
        codeunit "Item Attribute Data Restrict ori" = X,
        codeunit "Inventory Registration ori" = X,
        codeunit "Inventory Install ori" = X,
        codeunit "Inventory Upgrade ori" = X;
}
