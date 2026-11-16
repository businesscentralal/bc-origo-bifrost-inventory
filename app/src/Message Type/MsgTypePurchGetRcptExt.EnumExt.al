namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Registers the purchase invoice receipt line operation.</summary>
enumextension 10077030 "MsgType.PurchGetRcpt.Ext ori" extends "Message Type ori"
{
    /// <summary>Adds posted receipt lines to an open purchase invoice.</summary>
    value(10077030; "Purchase.PurchaseInvoice.GetReceiptLines")
    {
        Caption = 'Purchase.PurchaseInvoice.GetReceiptLines', Locked = true;
        Implementation = "Msg Interface ori" = "Purch Get Receipt Impl ori", "Msg Discovery ori" = "Purch Get Receipt Impl ori", "Msg Contract ori" = "Purch Get Receipt Impl ori";
    }
}
