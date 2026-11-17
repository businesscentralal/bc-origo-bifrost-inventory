namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

enumextension 10076847 "MsgType.PlanWksh.EnumExt ori" extends "Message Type ori"
{
    value(10076930; "Inventory.PlanningWorksheet.Calculate")
    {
        Caption = 'Inventory.PlanningWorksheet.Calculate', Locked = true;
        Implementation = "Msg Interface ori" = "Plan Wksh Calc Impl ori", "Msg Discovery ori" = "Plan Wksh Calc Impl ori", "Msg Contract ori" = "Plan Wksh Calc Impl ori";
    }
    value(10076931; "Inventory.PlanningWorksheet.CarryOut")
    {
        Caption = 'Inventory.PlanningWorksheet.CarryOut', Locked = true;
        Implementation = "Msg Interface ori" = "Plan Wksh Carry Impl ori", "Msg Discovery ori" = "Plan Wksh Carry Impl ori", "Msg Contract ori" = "Plan Wksh Carry Impl ori";
    }
}
