namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Registers inventory message types added after the first enum extension.
/// </summary>
enumextension 70013476 "MsgType.EnumExt Gaps ori" extends "Message Type ori"
{
    value(70013425; "Inventory.Tracking.Delete")
    {
        Caption = 'Inventory.Tracking.Delete', Locked = true;
        Implementation = "Msg Interface ori" = "Tracking Delete Impl ori", "Msg Discovery ori" = "Tracking Delete Impl ori", "Msg Contract ori" = "Tracking Delete Impl ori";
    }
    value(70013426; "Inventory.Reclassification.Check")
    {
        Caption = 'Inventory.Reclassification.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Reclass Check Impl ori", "Msg Discovery ori" = "Reclass Check Impl ori", "Msg Contract ori" = "Reclass Check Impl ori";
    }
}
