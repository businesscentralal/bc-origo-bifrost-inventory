namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076847 "MsgType.ItemTrace.Ext ori" extends "Message Type ori"
{
    value(10076930; "Inventory.ItemTracing.Get")
    {
        Caption = 'Inventory.ItemTracing.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Tracing Get Impl ori", "Msg Discovery ori" = "Item Tracing Get Impl ori", "Msg Contract ori" = "Item Tracing Get Impl ori";
    }
}
