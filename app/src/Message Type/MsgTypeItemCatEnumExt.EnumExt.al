namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013447 "MsgType.ItemCat.EnumExt ori" extends "Message Type ori"
{
    value(70013415; "Inventory.ItemCategory.Get")
    {
        Caption = 'Inventory.ItemCategory.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Category Get Impl ori", "Msg Discovery ori" = "Item Category Get Impl ori", "Msg Contract ori" = "Item Category Get Impl ori";
    }
    value(70013416; "Inventory.ItemCategory.Set")
    {
        Caption = 'Inventory.ItemCategory.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Item Category Set Impl ori", "Msg Discovery ori" = "Item Category Set Impl ori", "Msg Contract ori" = "Item Category Set Impl ori";
    }
}
