namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076844 "MsgType.Reserv.Create.Ext ori" extends "Message Type ori"
{
    value(10076893; "Inventory.Reservation.Create")
    {
        Caption = 'Inventory.Reservation.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Reservation Create Impl ori", "Msg Discovery ori" = "Reservation Create Impl ori", "Msg Contract ori" = "Reservation Create Impl ori";
    }
    value(10076889; "Inventory.Reclassification.PreviewPost")
    {
        Caption = 'Inventory.Reclassification.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Preview Impl ori", "Msg Discovery ori" = "Reclass Preview Impl ori", "Msg Contract ori" = "Reclass Preview Impl ori";
    }
    value(10076862; "Inventory.CostToGL.Test")
    {
        Caption = 'Inventory.CostToGL.Test', Locked = true;
        Implementation = "Msg Interface ori" = "Cost To GL Test Impl ori", "Msg Discovery ori" = "Cost To GL Test Impl ori", "Msg Contract ori" = "Cost To GL Test Impl ori";
    }
}
