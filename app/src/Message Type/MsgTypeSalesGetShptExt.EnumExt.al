namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076847 "MsgType.SalesGetShpt.Ext ori" extends "Message Type ori"
{
    value(10076930; "Sales.SalesInvoice.GetShipmentLines")
    {
        Caption = 'Sales.SalesInvoice.GetShipmentLines', Locked = true;
        Implementation = "Msg Interface ori" = "Sales Get Shipment Impl ori", "Msg Discovery ori" = "Sales Get Shipment Impl ori", "Msg Contract ori" = "Sales Get Shipment Impl ori";
    }
}
