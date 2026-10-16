namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013494 "MsgType.AvailPer.EnumExt ori" extends "Message Type ori"
{
    value(70013438; "Inventory.AvailabilityByPeriod.Get")
    {
        Caption = 'Inventory.AvailabilityByPeriod.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Avail. By Period Impl ori", "Msg Discovery ori" = "Avail. By Period Impl ori", "Msg Contract ori" = "Avail. By Period Impl ori";
    }
}
