namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076840 "MsgType.ItemRef.EnumExt ori" extends "Message Type ori"
{
    value(10076876; "Inventory.ItemReference.Resolve")
    {
        Caption = 'Inventory.ItemReference.Resolve', Locked = true;
        Implementation = "Msg Interface ori" = "Item Ref. Resolve Impl ori", "Msg Discovery ori" = "Item Ref. Resolve Impl ori", "Msg Contract ori" = "Item Ref. Resolve Impl ori";
    }
    /// <summary>Creates or changes item references.</summary>
    value(10076950; "Inventory.ItemReference.Set")
    {
        Caption = 'Inventory.ItemReference.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Item Ref. Set Impl ori", "Msg Discovery ori" = "Item Ref. Set Impl ori", "Msg Contract ori" = "Item Ref. Set Impl ori";
    }
}
