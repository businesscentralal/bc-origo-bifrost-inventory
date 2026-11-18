namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076835 "MsgType.AvailPer.EnumExt ori" extends "Message Type ori"
{
    value(10076857; "Inventory.AvailabilityByPeriod.Get")
    {
        Caption = 'Inventory.AvailabilityByPeriod.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Avail. By Period Impl ori", "Msg Discovery ori" = "Avail. By Period Impl ori", "Msg Contract ori" = "Avail. By Period Impl ori";
    }
    /// <summary>Reads the dated supply and demand timeline for one item.</summary>
    value(10076940; "Inventory.AvailabilityByEvent.Get")
    {
        Caption = 'Inventory.AvailabilityByEvent.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Avail. By Event Impl ori", "Msg Discovery ori" = "Avail. By Event Impl ori", "Msg Contract ori" = "Avail. By Event Impl ori";
    }
}
