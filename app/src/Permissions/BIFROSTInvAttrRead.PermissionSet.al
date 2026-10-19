namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;

/// <summary>
/// Preserves the existing Inventory read grants to standard attribute tables.
/// Included only through the corresponding Foundation role extension.
/// </summary>
permissionset 10036915 "BIFROST InvAttrRead ori"
{
    Assignable = false;

    Permissions =
        tabledata "Item Attribute" = R,
        tabledata "Item Attribute Value" = R,
        tabledata "Item Attribute Value Mapping" = R,
        tabledata "Item Attr. Value Translation" = R;
}
