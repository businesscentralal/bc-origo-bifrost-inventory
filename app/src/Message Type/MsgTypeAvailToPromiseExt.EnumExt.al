namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10077000 "MsgType.AvailToPromise.Ext ori" extends "Message Type ori"
{
    value(10077000; "Inventory.AvailableToPromise.Get")
    {
        Caption = 'Inventory.AvailableToPromise.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Avail. To Promise Impl ori", "Msg Discovery ori" = "Avail. To Promise Impl ori", "Msg Contract ori" = "Avail. To Promise Impl ori";
    }
}
