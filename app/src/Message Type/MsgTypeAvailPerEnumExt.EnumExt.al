namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076835 "MsgType.AvailPer.EnumExt ori" extends "Message Type ori"
{
    value(10076857; "Inventory.AvailabilityByPeriod.Get")
    {
        Caption = 'Inventory.AvailabilityByPeriod.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Avail. By Period Impl ori", "Msg Discovery ori" = "Avail. By Period Impl ori", "Msg Contract ori" = "Avail. By Period Impl ori";
    }
}
