namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013463 "MsgType.ItemChg.EnumExt ori" extends "Message Type ori"
{
    value(70013413; "Inventory.ItemCharge.Get")
    {
        Caption = 'Inventory.ItemCharge.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Charge Get Impl ori", "Msg Discovery ori" = "Item Charge Get Impl ori", "Msg Contract ori" = "Item Charge Get Impl ori";
    }
    value(70013414; "Inventory.ItemCharge.Assign")
    {
        Caption = 'Inventory.ItemCharge.Assign', Locked = true;
        Implementation = "Msg Interface ori" = "Item Charge Assign Impl ori", "Msg Discovery ori" = "Item Charge Assign Impl ori", "Msg Contract ori" = "Item Charge Assign Impl ori";
    }
}
