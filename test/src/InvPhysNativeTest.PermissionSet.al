namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;

/// <summary>Test caller with native journal write access and no Bifrost posting token.</summary>
permissionset 96936 "Inv Phys Native Test"
{
    Assignable = true;
    Caption = 'Inventory physical native test', MaxLength = 30;
    Permissions = tabledata "Item Journal Line" = RIMD;
}
