namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076848 "MsgType.ItemCreate.EnumExt ori" extends "Message Type ori"
{
    value(10076932; "Inventory.Item.Create")
    {
        Caption = 'Inventory.Item.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Create Impl ori", "Msg Discovery ori" = "Item Create Impl ori", "Msg Contract ori" = "Item Create Impl ori";
    }
}
