namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013429 "MsgType.ReservAuto.Ext ori" extends "Message Type ori"
{
    value(70013417; "Inventory.Reservation.AutoReserve")
    {
        Caption = 'Inventory.Reservation.AutoReserve', Locked = true;
        Implementation = "Msg Interface ori" = "Reserv. AutoReserve Impl ori", "Msg Discovery ori" = "Reserv. AutoReserve Impl ori", "Msg Contract ori" = "Reserv. AutoReserve Impl ori";
    }
    value(70013418; "Inventory.OrderTracking.Get")
    {
        Caption = 'Inventory.OrderTracking.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Order Tracking Get Impl ori", "Msg Discovery ori" = "Order Tracking Get Impl ori", "Msg Contract ori" = "Order Tracking Get Impl ori";
    }
}
