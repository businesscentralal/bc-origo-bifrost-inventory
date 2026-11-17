namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Registers the bounded purchase requisition worksheet operations.</summary>
enumextension 10076849 "MsgType.Requisition ori" extends "Message Type ori"
{
    value(10076941; "Purchase.Requisition.Calculate")
    {
        Caption = 'Purchase.Requisition.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Requisition Calc Impl ori", "Msg Discovery ori" = "Requisition Calc Impl ori", "Msg Contract ori" = "Requisition Calc Impl ori";
    }
    value(10076942; "Purchase.Requisition.CarryOut")
    {
        Caption = 'Purchase.Requisition.CarryOut', Locked = true;
        Implementation = "Msg Interface ori" = "Requisition Carry Impl ori", "Msg Discovery ori" = "Requisition Carry Impl ori", "Msg Contract ori" = "Requisition Carry Impl ori";
    }
}
