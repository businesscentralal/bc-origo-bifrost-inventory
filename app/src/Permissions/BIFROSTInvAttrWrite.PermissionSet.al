namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Microsoft.Inventory.Location;

/// <summary>
/// Preserves the existing Inventory write grants to standard attribute tables.
/// Also grants read on Item, Item Variant and Location for Inventory.AvailabilityByPeriod.Get.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036916 "BIFROST InvAttrWrite ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Attribute" = RIMD,
        tabledata "Item Attribute Value" = RIMD,
        tabledata "Item Attribute Value Mapping" = RIMD,
        tabledata "Item Attr. Value Translation" = RIMD,
        tabledata Item = R,
        tabledata "Item Variant" = R,
        tabledata Location = R;
}
