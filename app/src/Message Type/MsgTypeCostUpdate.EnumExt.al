namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Intentional guarded card-cost writes; Standard-costed items must use native revaluation.</summary>
enumextension 70013433 "MsgType Cost Update ori" extends "Message Type ori"
{
    value(70013437; "Inventory.Cost.Update")
    {
        Caption = 'Inventory.Cost.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Cost Update Impl ori", "Msg Discovery ori" = "Cost Update Impl ori", "Msg Contract ori" = "Cost Update Impl ori";
    }
}
