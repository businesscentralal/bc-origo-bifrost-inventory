namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Item.Catalog;

/// <summary>
/// Preserves the existing Inventory write grants to standard attribute tables.
/// Also grants read on Item and Item Reference for Inventory.ItemReference.Resolve.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036916 "BIFROST InvAttrWrite ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Category" = RIMD,
        tabledata "Item Attribute" = RIMD,
        tabledata "Item Attribute Value" = RIMD,
        tabledata "Item Attribute Value Mapping" = RIMD,
        tabledata "Item Attr. Value Translation" = RIMD,
        tabledata Item = R,
        tabledata "Item Reference" = R;
}
