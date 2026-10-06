namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013536 "MsgType.PhysRecord.EnumExt ori" extends "Message Type ori"
{
    value(70013447; "Inventory.PhysInventory.Record")
    {
        Caption = 'Inventory.PhysInventory.Record', Locked = true;
        Implementation = "Msg Interface ori" = "Phys. Invt. Record Impl ori", "Msg Discovery ori" = "Phys. Invt. Record Impl ori", "Msg Contract ori" = "Phys. Invt. Record Impl ori";
    }
}
