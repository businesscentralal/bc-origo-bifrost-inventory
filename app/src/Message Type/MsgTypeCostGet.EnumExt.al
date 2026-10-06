namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013537 "MsgType.CostGet.EnumExt ori" extends "Message Type ori"
{
    value(70013448; "Inventory.Cost.Get")
    {
        Caption = 'Inventory.Cost.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Cost Get Impl ori", "Msg Discovery ori" = "Cost Get Impl ori", "Msg Contract ori" = "Cost Get Impl ori";
    }
}
