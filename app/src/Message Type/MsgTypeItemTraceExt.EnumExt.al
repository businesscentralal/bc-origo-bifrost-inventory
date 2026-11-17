namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10077029 "MsgType.ItemTrace.Ext ori" extends "Message Type ori"
{
    value(10077031; "Inventory.ItemTracing.Get")
    {
        Caption = 'Inventory.ItemTracing.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Tracing Get Impl ori", "Msg Discovery ori" = "Item Tracing Get Impl ori", "Msg Contract ori" = "Item Tracing Get Impl ori";
    }
}
