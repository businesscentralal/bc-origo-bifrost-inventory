namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10036917 "MsgType.ItemRef.EnumExt ori" extends "Message Type ori"
{
    value(10036917; "Inventory.ItemReference.Resolve")
    {
        Caption = 'Inventory.ItemReference.Resolve', Locked = true;
        Implementation = "Msg Interface ori" = "Item Ref. Resolve Impl ori", "Msg Discovery ori" = "Item Ref. Resolve Impl ori", "Msg Contract ori" = "Item Ref. Resolve Impl ori";
    }
}
