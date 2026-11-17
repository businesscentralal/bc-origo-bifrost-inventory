namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076840 "MsgType.ItemRef.EnumExt ori" extends "Message Type ori"
{
    value(10076876; "Inventory.ItemReference.Resolve")
    {
        Caption = 'Inventory.ItemReference.Resolve', Locked = true;
        Implementation = "Msg Interface ori" = "Item Ref. Resolve Impl ori", "Msg Discovery ori" = "Item Ref. Resolve Impl ori", "Msg Contract ori" = "Item Ref. Resolve Impl ori";
    }
    value(10077020; "Inventory.ItemSubstitution.Get")
    {
        Caption = 'Inventory.ItemSubstitution.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Subst. Get Impl ori", "Msg Discovery ori" = "Item Subst. Get Impl ori", "Msg Contract ori" = "Item Subst. Get Impl ori";
    }
}
