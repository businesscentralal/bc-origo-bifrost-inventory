namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>Applies selected quantities and posts atomically, including rollback of native validation failures.</summary>
codeunit 10077023 "Partial Transfer Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        DocumentNo: Code[20];
        Ship: Boolean;

    trigger OnRun()
    var
        Header: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        PartialTransfer: Codeunit "Partial Transfer Mgt ori";
        Shipment: Codeunit "TransferOrder-Post Shipment";
        Receipt: Codeunit "TransferOrder-Post Receipt";
        Subscriber: Codeunit "Transfer Post Subscriber ori";
        Quantities: Dictionary of [Integer, Decimal];
        Response: JsonObject;
        Quantity: Decimal;
    begin
        Header.LockTable();
        Header.Get(DocumentNo);
        TransferLine.LockTable();
        if not PartialTransfer.ValidateRequest(Rec, Header, Ship, Quantities) then
            exit;
        TransferLine.SetRange("Document No.", DocumentNo);
        TransferLine.SetRange("Derived From Line No.", 0);
        if TransferLine.FindSet(true) then
            repeat
                Quantity := 0;
                if Quantities.ContainsKey(TransferLine."Line No.") then
                    Quantity := Quantities.Get(TransferLine."Line No.");
                if Ship then
                    TransferLine.Validate("Qty. to Ship", Quantity)
                else
                    TransferLine.Validate("Qty. to Receive", Quantity);
                TransferLine.Modify(true);
            until TransferLine.Next() = 0;
        Header.SetHideValidationDialog(true);
        BindSubscription(Subscriber);
        if Ship then begin
            Shipment.SetHideValidationDialog(true);
            Shipment.SetSuppressCommit(true);
            Shipment.Run(Header);
        end else begin
            Receipt.SetHideValidationDialog(true);
            Receipt.SetSuppressCommit(true);
            Receipt.Run(Header);
        end;
        UnbindSubscription(Subscriber);
        Response.Add('status', 'Success');
        Response.Add('documentNo', DocumentNo);
        Response.Add('postedShipmentNo', Subscriber.GetPostedShipmentNo());
        Response.Add('postedReceiptNo', Subscriber.GetPostedReceiptNo());
        Response.Add('postingDate', Format(Subscriber.GetPostingDate(), 0, 9));
        Response.Add('orderDeleted', not Header.Get(DocumentNo));
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>Selects the document and posting direction for the following isolated run.</summary>
    procedure Configure(OrderNo: Code[20]; PostShipment: Boolean)
    begin
        DocumentNo := OrderNo;
        Ship := PostShipment;
    end;
}
