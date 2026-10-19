namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Separate native posting and rollback preview for Revaluation batches.</summary>
enumextension 70013434 "MsgType Revaluation ori" extends "Message Type ori"
{
    value(70013438; "Inventory.Revaluation.Post")
    {
        Caption = 'Inventory.Revaluation.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Revaluation Post Impl ori", "Msg Discovery ori" = "Revaluation Post Impl ori", "Msg Contract ori" = "Revaluation Post Impl ori";
    }
    value(70013439; "Inventory.Revaluation.PreviewPost")
    {
        Caption = 'Inventory.Revaluation.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Reval Preview Impl ori", "Msg Discovery ori" = "Reval Preview Impl ori", "Msg Contract ori" = "Reval Preview Impl ori";
    }
}
