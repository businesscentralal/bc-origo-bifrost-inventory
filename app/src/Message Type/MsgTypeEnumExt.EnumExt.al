namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Extends Bifrost Foundation Message Type ori with inventory message types.
/// Captions are Locked because message identifiers are part of the public wire contract.
/// </summary>
enumextension 10076837 "MsgType.EnumExt ori" extends "Message Type ori"
{
    value(10076916; "Inventory.Attribute.Get")
    {
        Caption = 'Inventory.Attribute.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Get Impl ori", "Msg Discovery ori" = "Item Attribute Get Impl ori", "Msg Contract ori" = "Item Attribute Get Impl ori";
    }
    value(10076915; "Inventory.Attribute.Create")
    {
        Caption = 'Inventory.Attribute.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Create Impl ori", "Msg Discovery ori" = "Item Attribute Create Impl ori", "Msg Contract ori" = "Item Attribute Create Impl ori";
    }
    value(10076917; "Inventory.Attribute.Update")
    {
        Caption = 'Inventory.Attribute.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Update Impl ori", "Msg Discovery ori" = "Item Attribute Update Impl ori", "Msg Contract ori" = "Item Attribute Update Impl ori";
    }
    value(10076913; "Inventory.AttributeDefinition.Create")
    {
        Caption = 'Inventory.AttributeDefinition.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item AttrDef Create Impl ori", "Msg Discovery ori" = "Item AttrDef Create Impl ori", "Msg Contract ori" = "Item AttrDef Create Impl ori";
    }
    value(10076902; "Inventory.TransferOrder.Create")
    {
        Caption = 'Inventory.TransferOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Create Impl ori", "Msg Discovery ori" = "Transfer Order Create Impl ori", "Msg Contract ori" = "Transfer Order Create Impl ori";
    }
    value(10076907; "Inventory.TransferOrder.Release")
    {
        Caption = 'Inventory.TransferOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Transf. Order Release Impl ori", "Msg Discovery ori" = "Transf. Order Release Impl ori", "Msg Contract ori" = "Transf. Order Release Impl ori";
    }
    value(10076904; "Inventory.TransferOrder.Reopen")
    {
        Caption = 'Inventory.TransferOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Reopen Impl ori", "Msg Discovery ori" = "Transfer Order Reopen Impl ori", "Msg Contract ori" = "Transfer Order Reopen Impl ori";
    }
    value(10076903; "Inventory.TransferOrder.Post")
    {
        Caption = 'Inventory.TransferOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Post Impl ori", "Msg Discovery ori" = "Transfer Order Post Impl ori", "Msg Contract ori" = "Transfer Order Post Impl ori";
    }
    value(10076901; "Inventory.TransferOrder.PreviewPost")
    {
        Caption = 'Inventory.TransferOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Doc Prev. Post Impl ori", "Msg Discovery ori" = "Transf Doc Prev. Post Impl ori", "Msg Contract ori" = "Transf Doc Prev. Post Impl ori";
    }
    value(10076905; "Inventory.TransferOrder.Statistics")
    {
        Caption = 'Inventory.TransferOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Stats Impl ori", "Msg Discovery ori" = "Transfer Order Stats Impl ori", "Msg Contract ori" = "Transfer Order Stats Impl ori";
    }
    value(10076854; "Inventory.AssemblyOrder.Create")
    {
        Caption = 'Inventory.AssemblyOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Create Impl ori", "Msg Discovery ori" = "Assembly Order Create Impl ori", "Msg Contract ori" = "Assembly Order Create Impl ori";
    }
    value(10076850; "Inventory.AssemblyOrder.RefreshLines")
    {
        Caption = 'Inventory.AssemblyOrder.RefreshLines', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order RefreshLn Impl ori", "Msg Discovery ori" = "Asm. Order RefreshLn Impl ori", "Msg Contract ori" = "Asm. Order RefreshLn Impl ori";
    }
    value(10076851; "Inventory.AssemblyOrder.Release")
    {
        Caption = 'Inventory.AssemblyOrder.Release', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Release Impl ori", "Msg Discovery ori" = "Asm. Order Release Impl ori", "Msg Contract ori" = "Asm. Order Release Impl ori";
    }
    value(10076856; "Inventory.AssemblyOrder.Reopen")
    {
        Caption = 'Inventory.AssemblyOrder.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Reopen Impl ori", "Msg Discovery ori" = "Assembly Order Reopen Impl ori", "Msg Contract ori" = "Assembly Order Reopen Impl ori";
    }
    value(10076855; "Inventory.AssemblyOrder.Post")
    {
        Caption = 'Inventory.AssemblyOrder.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Order Post Impl ori", "Msg Discovery ori" = "Assembly Order Post Impl ori", "Msg Contract ori" = "Assembly Order Post Impl ori";
    }
    value(10076849; "Inventory.AssemblyOrder.PreviewPost")
    {
        Caption = 'Inventory.AssemblyOrder.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Doc Prev. Post Impl ori", "Msg Discovery ori" = "Asm. Doc Prev. Post Impl ori", "Msg Contract ori" = "Asm. Doc Prev. Post Impl ori";
    }
    value(10076853; "Inventory.AssemblyOrder.Statistics")
    {
        Caption = 'Inventory.AssemblyOrder.Statistics', Locked = true;
        Implementation = "Msg Interface ori" = "Asm. Order Statistics Impl ori", "Msg Discovery ori" = "Asm. Order Statistics Impl ori", "Msg Contract ori" = "Asm. Order Statistics Impl ori";
    }
    value(10076858; "Inventory.AdjustCost.Run")
    {
        Caption = 'Inventory.AdjustCost.Run', Locked = true;
        Implementation = "Msg Interface ori" = "Adjust Cost Run Impl ori", "Msg Discovery ori" = "Adjust Cost Run Impl ori", "Msg Contract ori" = "Adjust Cost Run Impl ori";
    }
    value(10076861; "Inventory.CostToGL.Post")
    {
        Caption = 'Inventory.CostToGL.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Cost To GL Post Impl ori", "Msg Discovery ori" = "Cost To GL Post Impl ori", "Msg Contract ori" = "Cost To GL Post Impl ori";
    }
    value(10076897; "Inventory.Tracking.Assign")
    {
        Caption = 'Inventory.Tracking.Assign', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Assign Impl ori", "Msg Discovery ori" = "Tracking Assign Impl ori", "Msg Contract ori" = "Tracking Assign Impl ori";
    }
    value(10076910; "Inventory.Transfer.UndoShipment")
    {
        Caption = 'Inventory.Transfer.UndoShipment', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Undo Shpt Impl ori", "Msg Discovery ori" = "Transfer Undo Shpt Impl ori", "Msg Contract ori" = "Transfer Undo Shpt Impl ori";
    }
    value(10076867; "Inventory.ItemApplication.Get")
    {
        Caption = 'Inventory.ItemApplication.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Get Impl ori", "Msg Discovery ori" = "Item Appl. Get Impl ori", "Msg Contract ori" = "Item Appl. Get Impl ori";
    }
    value(10076899; "Inventory.Tracking.Delete")
    {
        Caption = 'Inventory.Tracking.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Delete Impl ori", "Msg Discovery ori" = "Tracking Delete Impl ori", "Msg Contract ori" = "Tracking Delete Impl ori";
    }
    value(10076887; "Inventory.Reclassification.Check")
    {
        Caption = 'Inventory.Reclassification.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Check Impl ori", "Msg Discovery ori" = "Reclass Check Impl ori", "Msg Contract ori" = "Reclass Check Impl ori";
    }
    value(10076911; "Inventory.Transfer.UndoReceipt")
    {
        Caption = 'Inventory.Transfer.UndoReceipt', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Undo Rcpt Impl ori", "Msg Discovery ori" = "Transf Undo Rcpt Impl ori", "Msg Contract ori" = "Transf Undo Rcpt Impl ori";
    }
    value(10076869; "Inventory.ItemApplication.Unapply")
    {
        Caption = 'Inventory.ItemApplication.Unapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Unapply Impl ori", "Msg Discovery ori" = "Item Appl. Unapply Impl ori", "Msg Contract ori" = "Item Appl. Unapply Impl ori";
    }
    value(10076868; "Inventory.ItemApplication.Reapply")
    {
        Caption = 'Inventory.ItemApplication.Reapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Reapply Impl ori", "Msg Discovery ori" = "Item Appl. Reapply Impl ori", "Msg Contract ori" = "Item Appl. Reapply Impl ori";
    }
    value(10076909; "Inventory.Assembly.UndoPost")
    {
        Caption = 'Inventory.Assembly.UndoPost', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Undo Post Impl ori", "Msg Discovery ori" = "Assembly Undo Post Impl ori", "Msg Contract ori" = "Assembly Undo Post Impl ori";
    }
    value(10076888; "Inventory.Reclassification.Post")
    {
        Caption = 'Inventory.Reclassification.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Post Impl ori", "Msg Discovery ori" = "Reclass Post Impl ori", "Msg Contract ori" = "Reclass Post Impl ori";
    }
    value(10076878; "Inventory.Period.Get")
    {
        Caption = 'Inventory.Period.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Period Get Impl ori", "Msg Discovery ori" = "Period Get Impl ori", "Msg Contract ori" = "Period Get Impl ori";
    }
    value(10076877; "Inventory.Period.Close")
    {
        Caption = 'Inventory.Period.Close', Locked = true;
        Implementation = "Msg Interface ori" = "Period Close Impl ori", "Msg Discovery ori" = "Period Close Impl ori", "Msg Contract ori" = "Period Close Impl ori";
    }
    value(10076879; "Inventory.Period.Reopen")
    {
        Caption = 'Inventory.Period.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Period Reopen Impl ori", "Msg Discovery ori" = "Period Reopen Impl ori", "Msg Contract ori" = "Period Reopen Impl ori";
    }
    value(10076886; "Inventory.Price.Update")
    {
        Caption = 'Inventory.Price.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Price Update Impl ori", "Msg Discovery ori" = "Price Update Impl ori", "Msg Contract ori" = "Price Update Impl ori";
    }
    value(10076865; "Inventory.Revaluation.Calculate")
    {
        Caption = 'Inventory.Revaluation.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Revaluation Calc Impl ori", "Msg Discovery ori" = "Revaluation Calc Impl ori", "Msg Contract ori" = "Revaluation Calc Impl ori";
    }
}
