namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10077019 "MsgType.Nonstock.EnumExt ori" extends "Message Type ori"
{
    value(10077019; "Inventory.NonstockItem.Create")
    {
        Caption = 'Inventory.NonstockItem.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Nonstock Item Create Impl ori", "Msg Discovery ori" = "Nonstock Item Create Impl ori", "Msg Contract ori" = "Nonstock Item Create Impl ori";
    }
}
