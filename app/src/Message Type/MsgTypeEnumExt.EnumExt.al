namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10036892 "MsgType.EnumExt ori" extends "Message Type ori"
{
    value(10036893; "Inventory.Attribute.Get")
    {
        Caption = 'Inventory.Attribute.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Get Impl ori", "Msg Discovery ori" = "Item Attribute Get Impl ori", "Msg Contract ori" = "Item Attribute Get Impl ori";
    }
    value(10036894; "Inventory.Attribute.Create")
    {
        Caption = 'Inventory.Attribute.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Create Impl ori", "Msg Discovery ori" = "Item Attribute Create Impl ori", "Msg Contract ori" = "Item Attribute Create Impl ori";
    }
    value(10036895; "Inventory.Attribute.Update")
    {
        Caption = 'Inventory.Attribute.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Item Attribute Update Impl ori", "Msg Discovery ori" = "Item Attribute Update Impl ori", "Msg Contract ori" = "Item Attribute Update Impl ori";
    }
    value(10036896; "Inventory.AttributeDefinition.Create")
    {
        Caption = 'Inventory.AttributeDefinition.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Item AttrDef Create Impl ori", "Msg Discovery ori" = "Item AttrDef Create Impl ori", "Msg Contract ori" = "Item AttrDef Create Impl ori";
    }
    value(70013400; "Inventory.TransferOrder.Create")
    {
        Caption = 'Inventory.TransferOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Order Create Impl ori", "Msg Discovery ori" = "Transfer Order Create Impl ori", "Msg Contract ori" = "Transfer Order Create Impl ori";
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
    value(70013425; "Inventory.Tracking.Delete")
    {
        Caption = 'Inventory.Tracking.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Delete Impl ori", "Msg Discovery ori" = "Tracking Delete Impl ori", "Msg Contract ori" = "Tracking Delete Impl ori";
    }
    value(70013423; "Inventory.Transfer.UndoShipment")
    {
        Caption = 'Inventory.Transfer.UndoShipment', Locked = true;
        Implementation = "Msg Interface ori" = "Transfer Undo Shpt Impl ori", "Msg Discovery ori" = "Transfer Undo Shpt Impl ori", "Msg Contract ori" = "Transfer Undo Shpt Impl ori";
    }
    value(70013427; "Inventory.Transfer.UndoReceipt")
    {
        Caption = 'Inventory.Transfer.UndoReceipt', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Undo Rcpt Impl ori", "Msg Discovery ori" = "Transf Undo Rcpt Impl ori", "Msg Contract ori" = "Transf Undo Rcpt Impl ori";
    }
    value(70013430; "Inventory.Assembly.UndoPost")
    {
        Caption = 'Inventory.Assembly.UndoPost', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Undo Post Impl ori", "Msg Discovery ori" = "Assembly Undo Post Impl ori", "Msg Contract ori" = "Assembly Undo Post Impl ori";
    }
    value(70013424; "Inventory.ItemApplication.Get")
    {
        Caption = 'Inventory.ItemApplication.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Get Impl ori", "Msg Discovery ori" = "Item Appl. Get Impl ori", "Msg Contract ori" = "Item Appl. Get Impl ori";
    }
    value(70013428; "Inventory.ItemApplication.Unapply")
    {
        Caption = 'Inventory.ItemApplication.Unapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Unapply Impl ori", "Msg Discovery ori" = "Item Appl. Unapply Impl ori", "Msg Contract ori" = "Item Appl. Unapply Impl ori";
    }
    value(70013429; "Inventory.ItemApplication.Reapply")
    {
        Caption = 'Inventory.ItemApplication.Reapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Reapply Impl ori", "Msg Discovery ori" = "Item Appl. Reapply Impl ori", "Msg Contract ori" = "Item Appl. Reapply Impl ori";
    }
    value(70013426; "Inventory.Reclassification.Check")
    {
        Caption = 'Inventory.Reclassification.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Check Impl ori", "Msg Discovery ori" = "Reclass Check Impl ori", "Msg Contract ori" = "Reclass Check Impl ori";
    }
    value(70013431; "Inventory.Reclassification.Post")
    {
        Caption = 'Inventory.Reclassification.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Post Impl ori", "Msg Discovery ori" = "Reclass Post Impl ori", "Msg Contract ori" = "Reclass Post Impl ori";
    }
    value(70013432; "Inventory.Period.Get")
    {
        Caption = 'Inventory.Period.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Period Get Impl ori", "Msg Discovery ori" = "Period Get Impl ori", "Msg Contract ori" = "Period Get Impl ori";
    }
    value(70013433; "Inventory.Period.Close")
    {
        Caption = 'Inventory.Period.Close', Locked = true;
        Implementation = "Msg Interface ori" = "Period Close Impl ori", "Msg Discovery ori" = "Period Close Impl ori", "Msg Contract ori" = "Period Close Impl ori";
    }
    value(70013434; "Inventory.Period.Reopen")
    {
        Caption = 'Inventory.Period.Reopen', Locked = true;
        Implementation = "Msg Interface ori" = "Period Reopen Impl ori", "Msg Discovery ori" = "Period Reopen Impl ori", "Msg Contract ori" = "Period Reopen Impl ori";
    }
    value(70013435; "Inventory.Price.Update")
    {
        Caption = 'Inventory.Price.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Price Update Impl ori", "Msg Discovery ori" = "Price Update Impl ori", "Msg Contract ori" = "Price Update Impl ori";
    }
    value(70013436; "Inventory.Revaluation.Calculate")
    {
        Caption = 'Inventory.Revaluation.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Revaluation Calc Impl ori", "Msg Discovery ori" = "Revaluation Calc Impl ori", "Msg Contract ori" = "Revaluation Calc Impl ori";
    }
}
