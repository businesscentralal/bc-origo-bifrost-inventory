namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Registers inventory message types added after the first enum extension.
/// </summary>
enumextension 70013476 "MsgType.EnumExt Gaps ori" extends "Message Type ori"
{
    value(70013425; "Inventory.Tracking.Delete")
    {
        Caption = 'Inventory.Tracking.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Delete Impl ori", "Msg Discovery ori" = "Tracking Delete Impl ori", "Msg Contract ori" = "Tracking Delete Impl ori";
    }
    value(70013426; "Inventory.Reclassification.Check")
    {
        Caption = 'Inventory.Reclassification.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Check Impl ori", "Msg Discovery ori" = "Reclass Check Impl ori", "Msg Contract ori" = "Reclass Check Impl ori";
    }
    value(70013427; "Inventory.Transfer.UndoReceipt")
    {
        Caption = 'Inventory.Transfer.UndoReceipt', Locked = true;
        Implementation = "Msg Interface ori" = "Transf Undo Rcpt Impl ori", "Msg Discovery ori" = "Transf Undo Rcpt Impl ori", "Msg Contract ori" = "Transf Undo Rcpt Impl ori";
    }
    value(70013428; "Inventory.Assembly.UndoPost")
    {
        Caption = 'Inventory.Assembly.UndoPost', Locked = true;
        Implementation = "Msg Interface ori" = "Assembly Undo Post Impl ori", "Msg Discovery ori" = "Assembly Undo Post Impl ori", "Msg Contract ori" = "Assembly Undo Post Impl ori";
    }
    value(70013429; "Inventory.ItemApplication.Unapply")
    {
        Caption = 'Inventory.ItemApplication.Unapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Unapply Impl ori", "Msg Discovery ori" = "Item Appl. Unapply Impl ori", "Msg Contract ori" = "Item Appl. Unapply Impl ori";
    }
    value(70013430; "Inventory.ItemApplication.Reapply")
    {
        Caption = 'Inventory.ItemApplication.Reapply', Locked = true;
        Implementation = "Msg Interface ori" = "Item Appl. Reapply Impl ori", "Msg Discovery ori" = "Item Appl. Reapply Impl ori", "Msg Contract ori" = "Item Appl. Reapply Impl ori";
    }
}
