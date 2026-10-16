namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Location;

/// <summary>
/// Preserves the existing Inventory read grants to standard attribute tables.
/// Also grants read on Item, Item Variant and Location for Inventory.AvailabilityByPeriod.Get.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036915 "BIFROST InvAttrRead ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Attribute" = R,
        tabledata "Item Attribute Value" = R,
        tabledata "Item Attribute Value Mapping" = R,
        tabledata "Item Attr. Value Translation" = R,
        tabledata Item = R,
        tabledata "Item Variant" = R,
        tabledata Location = R;
}
