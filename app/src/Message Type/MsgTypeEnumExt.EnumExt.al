namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Bifrost Foundation Message Type ori with inventory message types.
/// Captions are Locked because message identifiers are part of the public wire contract.
/// </summary>
enumextension 10036892 "MsgType.EnumExt ori" extends "Message Type ori"
{
    value(10036893; "Item.Attribute.Get")
    {
        Caption = 'Item.Attribute.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Get Impl ori", "Msg Discovery ori" = "Item Attribute Get Impl ori", "Msg Contract ori" = "Item Attribute Get Impl ori";
    }
    value(10036894; "Item.Attribute.Create")
    {
        Caption = 'Item.Attribute.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Create Impl ori", "Msg Discovery ori" = "Item Attribute Create Impl ori", "Msg Contract ori" = "Item Attribute Create Impl ori";
    }
    value(10036895; "Item.Attribute.Update")
    {
        Caption = 'Item.Attribute.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Update Impl ori", "Msg Discovery ori" = "Item Attribute Update Impl ori", "Msg Contract ori" = "Item Attribute Update Impl ori";
    }
    value(10036896; "Item.AttributeDefinition.Create")
    {
        Caption = 'Item.AttributeDefinition.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item AttrDef Create Impl ori", "Msg Discovery ori" = "Item AttrDef Create Impl ori", "Msg Contract ori" = "Item AttrDef Create Impl ori";
    }
    value(70013400; "Inventory.TransferOrder.Create")
    {
        Caption = 'Inventory.TransferOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Create Impl ori", "Msg Discovery ori" = "Transfer Order Create Impl ori", "Msg Contract ori" = "Transfer Order Create Impl ori";
    }
    value(70013401; "Inventory.TransferOrder.Release")
    {
        Caption = 'Inventory.TransferOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Transf. Order Release Impl ori", "Msg Discovery ori" = "Transf. Order Release Impl ori", "Msg Contract ori" = "Transf. Order Release Impl ori";
    }
    value(70013402; "Inventory.TransferOrder.Reopen")
    {
        Caption = 'Inventory.TransferOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Reopen Impl ori", "Msg Discovery ori" = "Transfer Order Reopen Impl ori", "Msg Contract ori" = "Transfer Order Reopen Impl ori";
    }
    value(70013403; "Inventory.TransferOrder.Post")
    {
        Caption = 'Inventory.TransferOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Post Impl ori", "Msg Discovery ori" = "Transfer Order Post Impl ori", "Msg Contract ori" = "Transfer Order Post Impl ori";
    }
    value(70013404; "Inventory.TransferOrder.PreviewPost")
    {
        Caption = 'Inventory.TransferOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Doc Prev. Post Impl ori", "Msg Discovery ori" = "Transf Doc Prev. Post Impl ori", "Msg Contract ori" = "Transf Doc Prev. Post Impl ori";
    }
    value(70013405; "Inventory.TransferOrder.Statistics")
    {
        Caption = 'Inventory.TransferOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Stats Impl ori", "Msg Discovery ori" = "Transfer Order Stats Impl ori", "Msg Contract ori" = "Transfer Order Stats Impl ori";
    }
    value(70013406; "Inventory.AssemblyOrder.Create")
    {
        Caption = 'Inventory.AssemblyOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Create Impl ori", "Msg Discovery ori" = "Assembly Order Create Impl ori", "Msg Contract ori" = "Assembly Order Create Impl ori";
    }
    value(70013407; "Inventory.AssemblyOrder.RefreshLines")
    {
        Caption = 'Inventory.AssemblyOrder.RefreshLines', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order RefreshLn Impl ori", "Msg Discovery ori" = "Asm. Order RefreshLn Impl ori", "Msg Contract ori" = "Asm. Order RefreshLn Impl ori";
    }
    value(70013408; "Inventory.AssemblyOrder.Release")
    {
        Caption = 'Inventory.AssemblyOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Release Impl ori", "Msg Discovery ori" = "Asm. Order Release Impl ori", "Msg Contract ori" = "Asm. Order Release Impl ori";
    }
    value(70013409; "Inventory.AssemblyOrder.Reopen")
    {
        Caption = 'Inventory.AssemblyOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Reopen Impl ori", "Msg Discovery ori" = "Assembly Order Reopen Impl ori", "Msg Contract ori" = "Assembly Order Reopen Impl ori";
    }
    value(70013410; "Inventory.AssemblyOrder.Post")
    {
        Caption = 'Inventory.AssemblyOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Post Impl ori", "Msg Discovery ori" = "Assembly Order Post Impl ori", "Msg Contract ori" = "Assembly Order Post Impl ori";
    }
    value(70013411; "Inventory.AssemblyOrder.PreviewPost")
    {
        Caption = 'Inventory.AssemblyOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Doc Prev. Post Impl ori", "Msg Discovery ori" = "Asm. Doc Prev. Post Impl ori", "Msg Contract ori" = "Asm. Doc Prev. Post Impl ori";
    }
    value(70013412; "Inventory.AssemblyOrder.Statistics")
    {
        Caption = 'Inventory.AssemblyOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Statistics Impl ori", "Msg Discovery ori" = "Asm. Order Statistics Impl ori", "Msg Contract ori" = "Asm. Order Statistics Impl ori";
    }
    value(70013420; "Inventory.AdjustCost.Run")
    {
        Caption = 'Inventory.AdjustCost.Run', Locked = true;
        Implementation = "Msg Interface ori" = "Adjust Cost Run Impl ori", "Msg Discovery ori" = "Adjust Cost Run Impl ori", "Msg Contract ori" = "Adjust Cost Run Impl ori";
    }
    value(70013421; "Inventory.CostToGL.Post")
    {
        Caption = 'Inventory.CostToGL.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Cost To GL Post Impl ori", "Msg Discovery ori" = "Cost To GL Post Impl ori", "Msg Contract ori" = "Cost To GL Post Impl ori";
    }
    value(70013422; "Inventory.Tracking.Assign")
    {
        Caption = 'Inventory.Tracking.Assign', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Assign Impl ori", "Msg Discovery ori" = "Tracking Assign Impl ori", "Msg Contract ori" = "Tracking Assign Impl ori";
    }
    value(70013423; "Inventory.Transfer.UndoShipment")
    {
        Caption = 'Inventory.Transfer.UndoShipment', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Undo Ship Impl ori", "Msg Discovery ori" = "Transfer Undo Ship Impl ori", "Msg Contract ori" = "Transfer Undo Ship Impl ori";
    }
    value(70013424; "Inventory.ItemApplication.Get")
    {
        Caption = 'Inventory.ItemApplication.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl Get Impl ori", "Msg Discovery ori" = "Item Appl Get Impl ori", "Msg Contract ori" = "Item Appl Get Impl ori";
    }
}
