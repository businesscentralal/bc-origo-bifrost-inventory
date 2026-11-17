namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Registers the distinct native sales shipment and purchase receipt undo operations.</summary>
enumextension 10077025 "MsgType.PostedUndo.Ext ori" extends "Message Type ori"
{
    value(10077016; "Sales.Shipment.Undo")
    {
        Caption = 'Sales.Shipment.Undo', Locked = true, Comment = 'is-IS=Sales.Shipment.Undo';
        Implementation = "Msg Interface ori" = "Sales Undo Impl ori", "Msg Discovery ori" = "Sales Undo Impl ori", "Msg Contract ori" = "Sales Undo Impl ori";
    }
    value(10077017; "Purchase.Receipt.Undo")
    {
        Caption = 'Purchase.Receipt.Undo', Locked = true, Comment = 'is-IS=Purchase.Receipt.Undo';
        Implementation = "Msg Interface ori" = "Purchase Undo Impl ori", "Msg Discovery ori" = "Purchase Undo Impl ori", "Msg Contract ori" = "Purchase Undo Impl ori";
    }
}
