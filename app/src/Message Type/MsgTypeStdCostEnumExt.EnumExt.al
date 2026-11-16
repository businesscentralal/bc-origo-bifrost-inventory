namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Standard cost worksheet suggestion and implementation; neither operation posts a journal.</summary>
enumextension 10076848 "MsgType.StdCost.EnumExt ori" extends "Message Type ori"
{
    value(10076932; "Inventory.StandardCost.Suggest")
    {
        Caption = 'Inventory.StandardCost.Suggest', Locked = true;
        Implementation = "Msg Interface ori" = "Std. Cost Suggest Impl ori", "Msg Discovery ori" = "Std. Cost Suggest Impl ori", "Msg Contract ori" = "Std. Cost Suggest Impl ori";
    }
    value(10076933; "Inventory.StandardCost.Implement")
    {
        Caption = 'Inventory.StandardCost.Implement', Locked = true;
        Implementation = "Msg Interface ori" = "Std. Cost Implement Impl ori", "Msg Discovery ori" = "Std. Cost Implement Impl ori", "Msg Contract ori" = "Std. Cost Implement Impl ori";
    }
}
