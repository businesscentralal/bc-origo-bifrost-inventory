namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Preserves the existing Inventory write grants to standard attribute tables.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036916 "BIFROST InvAttrWrite ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Attribute" = RIMD,
        tabledata "Item Attribute Value" = RIMD,
        tabledata "Item Attribute Value Mapping" = RIMD,
        tabledata "Item Attr. Value Translation" = RIMD;
}
