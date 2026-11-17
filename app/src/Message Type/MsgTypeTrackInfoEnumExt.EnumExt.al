namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Reads the lot, serial or package information card of an item.</summary>
enumextension 10076915 "MsgType.TrackInfo.EnumExt ori" extends "Message Type ori"
{
    value(10077010; "Inventory.TrackingInfo.Get")
    {
        Caption = 'Inventory.TrackingInfo.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Info Get Impl ori", "Msg Discovery ori" = "Tracking Info Get Impl ori", "Msg Contract ori" = "Tracking Info Get Impl ori";
    }
}
