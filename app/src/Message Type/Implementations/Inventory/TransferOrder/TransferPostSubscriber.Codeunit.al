namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;

/// <summary>
/// Manual event subscriber that overrides Transfer Order posting options.
/// Bind before running codeunit 5706 "TransferOrder-Post (Yes/No)" to force a specific
/// combination of Ship / Receive / Direct Transfer posting without showing the StrMenu prompt.
/// It also runs the posting in batch mode, so native posting shows no dialog or message (a full
/// receive deletes the order and would otherwise show a message), and captures the numbers of the
/// posted shipment, receipt or direct transfer, which stay available after the order is deleted.
/// </summary>
codeunit 70013420 "Transfer Post Subscriber ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        CapturedShipmentNo: Code[20];
        CapturedReceiptNo: Code[20];
        CapturedPostingDate: Date;
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

    /// <summary>Returns the number of the transfer shipment (or direct transfer) posted while bound.</summary>
    /// <returns>The posted document number, or blank.</returns>
    internal procedure GetPostedShipmentNo(): Code[20]
    begin
        exit(CapturedShipmentNo);
    end;

    /// <summary>Returns the number of the transfer receipt (or direct transfer) posted while bound.</summary>
    /// <returns>The posted document number, or blank.</returns>
    internal procedure GetPostedReceiptNo(): Code[20]
    begin
        exit(CapturedReceiptNo);
    end;

    /// <summary>Returns the posting date of the last document posted while bound.</summary>
    /// <returns>The posting date, or 0D.</returns>
    internal procedure GetPostingDate(): Date
    begin
        exit(CapturedPostingDate);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post (Yes/No)", 'OnBeforePost', '', false, false)]
    local procedure PostAsBatch(var TransHeader: Record "Transfer Header"; var IsHandled: Boolean; var TransferOrderPostShipment: Codeunit "TransferOrder-Post Shipment"; var TransferOrderPostReceipt: Codeunit "TransferOrder-Post Receipt"; var PostBatch: Boolean; var TransferOrderPost: Enum "Transfer Order Post")
    begin
        // Batch mode hides the validation dialog of the shipment and receipt posting, including the
        // "posted and deleted" message that a full receive shows before its commit.
        PostBatch := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnAfterTransferOrderPostShipment', '', false, false)]
    local procedure CaptureShipment(var TransferHeader: Record "Transfer Header"; CommitIsSuppressed: Boolean; PreviewMode: Boolean; var TransferShipmentHeader: Record "Transfer Shipment Header"; InvtPickPutaway: Boolean)
    begin
        CapturedShipmentNo := TransferShipmentHeader."No.";
        CapturedPostingDate := TransferShipmentHeader."Posting Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnAfterTransferOrderPostReceipt', '', false, false)]
    local procedure CaptureReceipt(var TransferHeader: Record "Transfer Header"; CommitIsSuppressed: Boolean; PreviewMode: Boolean; var TransferReceiptHeader: Record "Transfer Receipt Header")
    begin
        CapturedReceiptNo := TransferReceiptHeader."No.";
        CapturedPostingDate := TransferReceiptHeader."Posting Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Transfer", 'OnAfterTransferOrderPostTransfer', '', false, false)]
    local procedure CaptureDirectTransfer(var TransferHeader: Record "Transfer Header"; var SuppressCommit: Boolean; PreviewMode: Boolean; var DirectTransHeader: Record "Direct Trans. Header"; InvtPickPutAway: Boolean)
    begin
        CapturedShipmentNo := DirectTransHeader."No.";
        CapturedReceiptNo := DirectTransHeader."No.";
        CapturedPostingDate := DirectTransHeader."Posting Date";
    end;
}
