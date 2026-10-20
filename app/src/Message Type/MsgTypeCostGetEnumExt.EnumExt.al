namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Costing message types: cost read, guarded card-cost writes and native revaluation posting and preview.</summary>
enumextension 10076836 "MsgType.CostGet.EnumExt ori" extends "Message Type ori"
{
    value(70013448; "Inventory.Cost.Get")
    {
        Caption = 'Inventory.Cost.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Cost Get Impl ori", "Msg Discovery ori" = "Cost Get Impl ori", "Msg Contract ori" = "Cost Get Impl ori";
    }
    value(70013437; "Inventory.Cost.Update")
    {
        Caption = 'Inventory.Cost.Update', Locked = true;
        Implementation = "Msg Interface ori" = "Cost Update Impl ori", "Msg Discovery ori" = "Cost Update Impl ori", "Msg Contract ori" = "Cost Update Impl ori";
    }
    value(70013438; "Inventory.Revaluation.Post")
    {
        Caption = 'Inventory.Revaluation.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Revaluation Post Impl ori", "Msg Discovery ori" = "Revaluation Post Impl ori", "Msg Contract ori" = "Revaluation Post Impl ori";
    }
    value(70013413; "Inventory.Revaluation.PreviewPost")
    {
        Caption = 'Inventory.Revaluation.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Reval Preview Impl ori", "Msg Discovery ori" = "Reval Preview Impl ori", "Msg Contract ori" = "Reval Preview Impl ori";
    }
}
