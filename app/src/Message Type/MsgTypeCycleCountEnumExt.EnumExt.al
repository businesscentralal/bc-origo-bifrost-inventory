namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076870 "MsgType.CycleCount.EnumExt ori" extends "Message Type ori"
{
    value(10076970; "Inventory.CycleCount.Calculate")
    {
        Caption = 'Inventory.CycleCount.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Cycle Count Calc Impl ori", "Msg Discovery ori" = "Cycle Count Calc Impl ori", "Msg Contract ori" = "Cycle Count Calc Impl ori";
    }
}
