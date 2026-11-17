namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Adds dedicated sales and purchase price-list maintenance.</summary>
enumextension 10076980 "MsgType.PriceList.Ext ori" extends "Message Type ori"
{
    value(10076980; "Price.List.Set")
    {
        Caption = 'Price.List.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Price List Set Impl ori", "Msg Discovery ori" = "Price List Set Impl ori", "Msg Contract ori" = "Price List Set Impl ori";
    }
    value(10076981; "Price.List.Activate")
    {
        Caption = 'Price.List.Activate', Locked = true;
        Implementation = "Msg Interface ori" = "Price List Activate Impl ori", "Msg Discovery ori" = "Price List Activate Impl ori", "Msg Contract ori" = "Price List Activate Impl ori";
    }
}
