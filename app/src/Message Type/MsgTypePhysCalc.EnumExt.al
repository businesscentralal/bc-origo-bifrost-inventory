namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013535 "MsgType.PhysCalc.EnumExt ori" extends "Message Type ori"
{
    value(70013446; "Inventory.PhysInventory.Calculate")
    {
        Caption = 'Inventory.PhysInventory.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Invt. Calc Impl ori", "Msg Discovery ori" = "Phys. Invt. Calc Impl ori", "Msg Contract ori" = "Phys. Invt. Calc Impl ori";
    }
}
