namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013479 "MsgType.ItemRef.EnumExt ori" extends "Message Type ori"
{
    value(70013437; "Inventory.ItemReference.Resolve")
    {
        Caption = 'Inventory.ItemReference.Resolve', Locked = true;
        Implementation = "Msg Interface ori" = "Item Ref. Resolve Impl ori", "Msg Discovery ori" = "Item Ref. Resolve Impl ori", "Msg Contract ori" = "Item Ref. Resolve Impl ori";
    }
}
