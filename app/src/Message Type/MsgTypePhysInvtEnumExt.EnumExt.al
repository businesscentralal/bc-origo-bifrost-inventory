namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076841 "MsgType.PhysInvt.EnumExt ori" extends "Message Type ori"
{
    value(10076883; "Inventory.PhysInventory.Calculate")
    {
        Caption = 'Inventory.PhysInventory.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Inv. Calc Impl ori", "Msg Discovery ori" = "Phys. Inv. Calc Impl ori", "Msg Contract ori" = "Phys. Inv. Calc Impl ori";
    }
    value(10076881; "Inventory.PhysInventory.Post")
    {
        Caption = 'Inventory.PhysInventory.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Invt. Post Impl ori", "Msg Discovery ori" = "Phys. Invt. Post Impl ori", "Msg Contract ori" = "Phys. Invt. Post Impl ori";
    }
    value(10076884; "Inventory.PhysInventory.Check")
    {
        Caption = 'Inventory.PhysInventory.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Inv. Check Impl ori", "Msg Discovery ori" = "Phys. Inv. Check Impl ori", "Msg Contract ori" = "Phys. Inv. Check Impl ori";
    }
    value(10076885; "Inventory.PhysInventory.PreviewPost")
    {
        Caption = 'Inventory.PhysInventory.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Inv. Preview Impl ori", "Msg Discovery ori" = "Phys. Inv. Preview Impl ori", "Msg Contract ori" = "Phys. Inv. Preview Impl ori";
    }
    value(10076924; "Inventory.PhysInventory.RecordCount")
    {
        Caption = 'Inventory.PhysInventory.RecordCount', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Invt. Record Impl ori", "Msg Discovery ori" = "Phys. Invt. Record Impl ori", "Msg Contract ori" = "Phys. Invt. Record Impl ori";
    }
}
