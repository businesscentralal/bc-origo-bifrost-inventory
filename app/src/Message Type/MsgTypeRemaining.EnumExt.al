namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 70013531 "MsgType.Reserv.Create.Ext ori" extends "Message Type ori"
{
    value(70013442; "Inventory.Reservation.Create")
    {
        Caption = 'Inventory.Reservation.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Reservation Create Impl ori", "Msg Discovery ori" = "Reservation Create Impl ori", "Msg Contract ori" = "Reservation Create Impl ori";
    }
    value(70013443; "Inventory.Reclassification.PreviewPost")
    {
        Caption = 'Inventory.Reclassification.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Preview Impl ori", "Msg Discovery ori" = "Reclass Preview Impl ori", "Msg Contract ori" = "Reclass Preview Impl ori";
    }
    value(70013444; "Inventory.CostToGL.Test")
    {
        Caption = 'Inventory.CostToGL.Test', Locked = true;
        Implementation = "Msg Interface ori" = "Cost To GL Test Impl ori", "Msg Discovery ori" = "Cost To GL Test Impl ori", "Msg Contract ori" = "Cost To GL Test Impl ori";
    }
}
