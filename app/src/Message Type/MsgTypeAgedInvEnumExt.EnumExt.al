namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Inventory.AgedInventory.Get: stock quantity and value per age bucket.</summary>
enumextension 10076851 "MsgType.AgedInv.EnumExt ori" extends "Message Type ori"
{
    value(10076948; "Inventory.AgedInventory.Get")
    {
        Caption = 'Inventory.AgedInventory.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Aged Inventory Get Impl ori", "Msg Discovery ori" = "Aged Inventory Get Impl ori", "Msg Contract ori" = "Aged Inventory Get Impl ori";
    }
}
