namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076846 "MsgType.TrackAvail.EnumExt ori" extends "Message Type ori"
{
    value(10076898; "Inventory.TrackingAvailability.Get")
    {
        Caption = 'Inventory.TrackingAvailability.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Avail. Get Impl ori", "Msg Discovery ori" = "Tracking Avail. Get Impl ori", "Msg Contract ori" = "Tracking Avail. Get Impl ori";
    }
    value(10076900; "Inventory.Tracking.Get")
    {
        Caption = 'Inventory.Tracking.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Get Impl ori", "Msg Discovery ori" = "Tracking Get Impl ori", "Msg Contract ori" = "Tracking Get Impl ori";
    }
}
