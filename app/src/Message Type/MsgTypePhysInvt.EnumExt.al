namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013534 "MsgType.PhysInvt.EnumExt ori" extends "Message Type ori"
{
    value(70013446; "Inventory.PhysInventory.Calculate")
    {
        Caption = 'Inventory.PhysInventory.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Inv. Calc Impl ori", "Msg Discovery ori" = "Phys. Inv. Calc Impl ori", "Msg Contract ori" = "Phys. Inv. Calc Impl ori";
    }
    value(70013445; "Inventory.PhysInventory.Post")
    {
        Caption = 'Inventory.PhysInventory.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Invt. Post Impl ori", "Msg Discovery ori" = "Phys. Invt. Post Impl ori", "Msg Contract ori" = "Phys. Invt. Post Impl ori";
    }
}
