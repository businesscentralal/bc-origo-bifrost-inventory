namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Registers the native physical inventory order lifecycle.</summary>
enumextension 10076860 "MsgType.PhysOrder.Ext ori" extends "Message Type ori"
{
    /// <summary>Runs the native order create operation.</summary>
    value(10076960; "Inventory.PhysInventoryOrder.Create")
    {
        Caption = 'Inventory.PhysInventoryOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Phys Order Create Impl ori", "Msg Discovery ori" = "Phys Order Create Impl ori", "Msg Contract ori" = "Phys Order Create Impl ori";
    }
    /// <summary>Runs the native order finish operation.</summary>
    value(10076961; "Inventory.PhysInventoryOrder.Finish")
    {
        Caption = 'Inventory.PhysInventoryOrder.Finish', Locked = true;
        Implementation = "Msg Interface ori" = "Phys Order Finish Impl ori", "Msg Discovery ori" = "Phys Order Finish Impl ori", "Msg Contract ori" = "Phys Order Finish Impl ori";
    }
    /// <summary>Runs the native order post operation.</summary>
    value(10076962; "Inventory.PhysInventoryOrder.Post")
    {
        Caption = 'Inventory.PhysInventoryOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Phys Order Post Impl ori", "Msg Discovery ori" = "Phys Order Post Impl ori", "Msg Contract ori" = "Phys Order Post Impl ori";
    }
}
