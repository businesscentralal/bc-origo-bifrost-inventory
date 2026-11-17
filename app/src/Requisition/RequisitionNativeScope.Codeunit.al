namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;

/// <summary>Scopes native calculation deletion and collects documents created by one bound call.</summary>
codeunit 10076945 "Requisition Native Scope ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        TemplateName: Code[10];
        BatchName: Code[10];
        PurchaseOrders: List of [Code[20]];
        TransferOrders: List of [Code[20]];

    /// <summary>Sets the worksheet boundary before binding this instance to native events.</summary>
    procedure Initialize(NewTemplateName: Code[10]; NewBatchName: Code[10])
    begin
        TemplateName := NewTemplateName;
        BatchName := NewBatchName;
        Clear(PurchaseOrders);
        Clear(TransferOrders);
    end;

    /// <summary>Returns only document numbers captured from native insertion events in this call.</summary>
    procedure GetOrders(var Purchases: JsonArray; var Transfers: JsonArray)
    var
        OrderNo: Code[20];
        Entry: JsonObject;
    begin
        Clear(Purchases);
        Clear(Transfers);
        foreach OrderNo in PurchaseOrders do begin
            Clear(Entry);
            Entry.Add('orderNo', OrderNo);
            Purchases.Add(Entry);
        end;
        foreach OrderNo in TransferOrders do begin
            Clear(Entry);
            Entry.Add('orderNo', OrderNo);
            Transfers.Add(Entry);
        end;
    end;

    [EventSubscriber(ObjectType::Report, Report::"Calculate Plan - Req. Wksh.", OnBeforeDeleteReqLines, '', false, false)]
    local procedure ScopeCalculation(Item: Record Item; var PurchReqLine: Record "Requisition Line"; var ReqLineExtern: Record "Requisition Line"; var IsHandled: Boolean; InventoryProfileOffsetting: Codeunit "Inventory Profile Offsetting")
    begin
        // Native report 699 otherwise deletes matching items in other worksheets too.
        PurchReqLine.SetRange("Worksheet Template Name", TemplateName);
        PurchReqLine.SetRange("Journal Batch Name", BatchName);
        ReqLineExtern.SetRange("Worksheet Template Name", TemplateName);
        ReqLineExtern.SetRange("Journal Batch Name", BatchName);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Req. Wksh.-Make Order", OnCodeOnBeforeInitProgressWindow, '', false, false)]
    local procedure HideProgress(ReqTemplate: Record "Req. Wksh. Template"; var HideProgressWindow: Boolean)
    begin
        HideProgressWindow := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Req. Wksh.-Make Order", OnAfterInsertPurchOrderHeader, '', false, false)]
    local procedure CapturePurchase(var RequisitionLine: Record "Requisition Line"; var PurchaseOrderHeader: Record "Purchase Header"; CommitIsSuppressed: Boolean; SpecialOrder: Boolean)
    begin
        if not PurchaseOrders.Contains(PurchaseOrderHeader."No.") then
            PurchaseOrders.Add(PurchaseOrderHeader."No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnInsertTransHeaderOnAfterTransHeaderInsert, '', false, false)]
    local procedure CaptureTransfer(var TransHeader: Record "Transfer Header"; ReqLine: Record "Requisition Line")
    begin
        if not TransferOrders.Contains(TransHeader."No.") then
            TransferOrders.Add(TransHeader."No.");
    end;
}
