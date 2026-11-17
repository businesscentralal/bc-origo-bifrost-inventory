namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076995 "MsgType.SKU.EnumExt ori" extends "Message Type ori"
{
    value(10076995; "Inventory.SKU.Create")
    {
        Caption = 'Inventory.SKU.Create', Locked = true;
        Implementation = "Msg Interface ori" = "SKU Create Impl ori", "Msg Discovery ori" = "SKU Create Impl ori", "Msg Contract ori" = "SKU Create Impl ori";
    }
    value(10076996; "Inventory.SKU.Get")
    {
        Caption = 'Inventory.SKU.Get', Locked = true;
        Implementation = "Msg Interface ori" = "SKU Get Impl ori", "Msg Discovery ori" = "SKU Get Impl ori", "Msg Contract ori" = "SKU Get Impl ori";
    }
}
