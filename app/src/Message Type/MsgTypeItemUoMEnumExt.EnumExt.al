namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10077015 "MsgType.ItemUoM.EnumExt ori" extends "Message Type ori"
{
    value(10077011; "Inventory.ItemUnitOfMeasure.Get")
    {
        Caption = 'Inventory.ItemUnitOfMeasure.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item UoM Get Impl ori", "Msg Discovery ori" = "Item UoM Get Impl ori", "Msg Contract ori" = "Item UoM Get Impl ori";
    }
    value(10077012; "Inventory.ItemUnitOfMeasure.Create")
    {
        Caption = 'Inventory.ItemUnitOfMeasure.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item UoM Create Impl ori", "Msg Discovery ori" = "Item UoM Create Impl ori", "Msg Contract ori" = "Item UoM Create Impl ori";
    }
}
