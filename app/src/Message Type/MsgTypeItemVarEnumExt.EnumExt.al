namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076890 "MsgType.ItemVar.EnumExt ori" extends "Message Type ori"
{
    value(10076990; "Inventory.ItemVariant.Get")
    {
        Caption = 'Inventory.ItemVariant.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Variant Get Impl ori", "Msg Discovery ori" = "Item Variant Get Impl ori", "Msg Contract ori" = "Item Variant Get Impl ori";
    }
    value(10076991; "Inventory.ItemVariant.Create")
    {
        Caption = 'Inventory.ItemVariant.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Variant Create Impl ori", "Msg Discovery ori" = "Item Variant Create Impl ori", "Msg Contract ori" = "Item Variant Create Impl ori";
    }
}
