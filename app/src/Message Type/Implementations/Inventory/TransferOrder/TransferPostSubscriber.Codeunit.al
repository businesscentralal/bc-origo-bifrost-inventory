namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;

/// <summary>
/// Manual event subscriber that overrides Transfer Order posting options.
/// Bind before running codeunit 5706 "TransferOrder-Post (Yes/No)" to force a specific
/// combination of Ship / Receive / Direct Transfer posting without showing the StrMenu prompt.
/// </summary>
codeunit 70013420 "Transfer Post Subscriber ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        ChosenPostShipment: Boolean;
        ChosenPostReceipt: Boolean;
        ChosenPostTransfer: Boolean;

    /// <summary>
    /// Configures which sub-postings the bound TransferOrder-Post (Yes/No) run should perform.
    /// </summary>
    internal procedure SetChoices(PostShipment: Boolean; PostReceipt: Boolean; PostTransfer: Boolean)
    begin
        ChosenPostShipment := PostShipment;
        ChosenPostReceipt := PostReceipt;
        ChosenPostTransfer := PostTransfer;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post (Yes/No)", 'OnBeforeGetPostingOptions', '', false, false)]
    local procedure OverridePostingOptions(TransferHeader: Record "Transfer Header"; Selection: Option; var PostShipment: Boolean; var PostReceipt: Boolean; var IsHandled: Boolean; var PostTransfer: Boolean; var DefaultNumber: Integer; PostBatch: Boolean; PreviewMode: Boolean)
    begin
        PostShipment := ChosenPostShipment;
        PostReceipt := ChosenPostReceipt;
        PostTransfer := ChosenPostTransfer;
        IsHandled := true;
    end;
}
