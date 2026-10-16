namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
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
        CapturedReceiptNo: Code[20];
        CapturedShipmentNo: Code[20];
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

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure CapturePostedDocumentNos(var Rec: Record "Transfer Header"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Last Receipt No." <> '' then
            CapturedReceiptNo := Rec."Last Receipt No.";
        if Rec."Last Shipment No." <> '' then
            CapturedShipmentNo := Rec."Last Shipment No.";
        if Rec."Posting Date" <> 0D then
            CapturedPostingDate := Rec."Posting Date";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Receipt Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure CaptureInsertedReceipt(var Rec: Record "Transfer Receipt Header"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        CapturedReceiptNo := Rec."No.";
        if Rec."Posting Date" <> 0D then
            CapturedPostingDate := Rec."Posting Date";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure CaptureInsertedTransferReceiptLedger(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Document Type" <> Rec."Document Type"::"Transfer Receipt" then
            exit;
        if Rec."Document No." = '' then
            exit;
        CapturedReceiptNo := Rec."Document No.";
        if Rec."Posting Date" <> 0D then
            CapturedPostingDate := Rec."Posting Date";
    end;

    internal procedure GetCapturedReceiptNo(): Code[20]
    begin
        exit(CapturedReceiptNo);
    end;

    internal procedure GetCapturedShipmentNo(): Code[20]
    begin
        exit(CapturedShipmentNo);
    end;

    internal procedure GetCapturedPostingDate(): Date
    begin
        exit(CapturedPostingDate);
    end;
}
