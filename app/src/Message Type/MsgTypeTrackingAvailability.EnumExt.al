namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013543 "MsgType.TrackAvail.EnumExt ori" extends "Message Type ori"
{
    value(70013446; "Inventory.TrackingAvailability.Get")
    {
        Caption = 'Inventory.TrackingAvailability.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Avail. Get Impl ori", "Msg Discovery ori" = "Tracking Avail. Get Impl ori", "Msg Contract ori" = "Tracking Avail. Get Impl ori";
    }
}
