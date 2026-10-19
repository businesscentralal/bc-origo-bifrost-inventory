namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Item.Catalog;

/// <summary>
/// Preserves the existing Inventory read grants to standard attribute tables.
/// Also grants read on Item and Item Reference for Inventory.ItemReference.Resolve.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036915 "BIFROST InvAttrRead ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Category" = R,
        tabledata "Item Attribute" = R,
        tabledata "Item Attribute Value" = R,
        tabledata "Item Attribute Value Mapping" = R,
        tabledata "Item Attr. Value Translation" = R,
        tabledata Item = R,
        tabledata "Item Reference" = R;
}
