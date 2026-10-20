namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076839 "MsgType.ItemChg.EnumExt ori" extends "Message Type ori"
{
    value(10036920; "Inventory.ItemCharge.Get")
    {
        Caption = 'Inventory.ItemCharge.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Charge Get Impl ori", "Msg Discovery ori" = "Item Charge Get Impl ori", "Msg Contract ori" = "Item Charge Get Impl ori";
    }
    value(10036919; "Inventory.ItemCharge.Assign")
    {
        Caption = 'Inventory.ItemCharge.Assign', Locked = true;
        Implementation = "Msg Interface ori" = "Item Charge Assign Impl ori", "Msg Discovery ori" = "Item Charge Assign Impl ori", "Msg Contract ori" = "Item Charge Assign Impl ori";
    }
}
