namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076847 "MsgType.PurchRet.EnumExt ori" extends "Message Type ori"
{
    value(10076930; "Purchase.ReturnOrder.CreateFromPosted")
    {
        Caption = 'Purchase.ReturnOrder.CreateFromPosted', Locked = true;
        Implementation = "Msg Interface ori" = "Purch. Return Create Impl ori", "Msg Discovery ori" = "Purch. Return Create Impl ori", "Msg Contract ori" = "Purch. Return Create Impl ori";
    }
}
