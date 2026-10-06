namespace Origo.Bifrost.Inventory;

/// <summary>
/// Company-level inventory domains that can be turned off on Inventory Setup.
/// </summary>
enum 70013450 "Inventory Domain ori"
{
    Extensible = false;
    Access = Internal;

    value(0; Attributes)
    {
        Caption = 'Attributes', Comment = 'is-IS=Eiginleikar';
    }
    value(1; TransferOrders)
    {
        Caption = 'Transfer Orders', Comment = 'is-IS=Flutningspantanir';
    }
    value(2; Assembly)
    {
        Caption = 'Assembly', Comment = 'is-IS=Samsetning';
    }
    value(3; Reservations)
    {
        Caption = 'Reservations', Comment = 'is-IS=Frátektir';
    }
    value(4; ItemTracking)
    {
        Caption = 'Item Tracking', Comment = 'is-IS=Vörurakning';
    }
    value(5; PhysInventory)
    {
        Caption = 'Physical Inventory', Comment = 'is-IS=Birgðatalning';
    }
    value(6; Costing)
    {
        Caption = 'Costing', Comment = 'is-IS=Kostnaður';
    }
    value(7; Reclassification)
    {
        Caption = 'Reclassification', Comment = 'is-IS=Endurflokkun';
    }
    value(8; ItemApplication)
    {
        Caption = 'Item Application', Comment = 'is-IS=Vörujöfnun';
    }
    value(9; InventoryPeriod)
    {
        Caption = 'Inventory Period', Comment = 'is-IS=Birgðatímabil';
    }
    value(10; ItemPrice)
    {
        Caption = 'Item Price', Comment = 'is-IS=Vöruverð';
    }
}
