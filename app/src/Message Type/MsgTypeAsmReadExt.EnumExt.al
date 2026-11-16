namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076960 "MsgType.AsmRead.Ext ori" extends "Message Type ori"
{
    value(10076960; "Inventory.AssemblyToOrder.Get")
    {
        Caption = 'Inventory.AssemblyToOrder.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. To Order Get Impl ori", "Msg Discovery ori" = "Asm. To Order Get Impl ori", "Msg Contract ori" = "Asm. To Order Get Impl ori";
    }
    value(10076961; "Inventory.AssemblyBOM.Get")
    {
        Caption = 'Inventory.AssemblyBOM.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly BOM Get Impl ori", "Msg Discovery ori" = "Assembly BOM Get Impl ori", "Msg Contract ori" = "Assembly BOM Get Impl ori";
    }
}
