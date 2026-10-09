namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013492 "MsgType.Reserv.EnumExt ori" extends "Message Type ori"
{
    value(70013440; "Inventory.Reservation.Get")
    {
        Caption = 'Inventory.Reservation.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Reservation Get Impl ori", "Msg Discovery ori" = "Reservation Get Impl ori", "Msg Contract ori" = "Reservation Get Impl ori";
    }
    value(70013441; "Inventory.Reservation.Cancel")
    {
        Caption = 'Inventory.Reservation.Cancel', Locked = true;
        Implementation = "Msg Interface ori" = "Reservation Cancel Impl ori", "Msg Discovery ori" = "Reservation Cancel Impl ori", "Msg Contract ori" = "Reservation Cancel Impl ori";
    }
}
