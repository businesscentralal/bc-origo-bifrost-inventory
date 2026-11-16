namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076906 "MsgType.SalesRetOrd.Ext ori" extends "Message Type ori"
{
    value(10077030; "Sales.ReturnOrder.CreateFromPosted")
    {
        Caption = 'Sales.ReturnOrder.CreateFromPosted', Locked = true;
        Implementation = "Msg Interface ori" = "Sales Ret. Ord. Post. Impl ori", "Msg Discovery ori" = "Sales Ret. Ord. Post. Impl ori", "Msg Contract ori" = "Sales Ret. Ord. Post. Impl ori";
    }
}
