namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Post message type.
/// Posts a transfer order (ship and/or receive) via codeunit 5706 "TransferOrder-Post (Yes/No)".
/// Posting type:
///   * Non-direct transfer: caller must specify postingType = "Ship" or "Receive".
///   * Direct transfer: postingType is ignored — BC reads "Direct Transfer Posting" from
///     Inventory Setup and decides between Receipt+Shipment or single Direct Transfer.
/// </summary>

using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013415 "Transfer Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        TransferHeader: Record "Transfer Header";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        if not TransferHeader.WritePermission() then
            exit(false);
        exit(PostingGate.HasPostingPermission());
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Posts a transfer order (ship/receive, or ship+receive for direct transfers).');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post transfer, ship transfer order, receive transfer order, goods arrived at the other warehouse, direct transfer', Comment = 'is-IS=bóka millifærslu, afhenda millifærslupöntun, taka á móti millifærslupöntun, móttekið í hinni birgðageymslunni, bein millifærsla';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Transfer Order Post Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        TransferOrderPostYesNo: Codeunit "TransferOrder-Post (Yes/No)";
        TransferPostSubscriber: Codeunit "Transfer Post Subscriber ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        PostingTypeText: Text;
        DocumentNo: Code[20];
        DirectTransfer: Boolean;
        PostShipment: Boolean;
        PostReceipt: Boolean;
        PostTransfer: Boolean;
        xLastShipmentNo: Code[20];
        xLastReceiptNo: Code[20];
        MissingPostingTypeErr: Label 'For a non-direct transfer order, postingType must be "Ship" or "Receive".', Locked = true;
        InvalidPostingTypeErr: Label 'postingType must be "Ship", "Receive", or "ShipReceive". Received: %1', Comment = '%1 = received value', Locked = true;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument) then
            exit;

        if not Argument.FindTransferHeader(TransferHeader) then
            exit;

        DocumentNo := TransferHeader."No.";
        DirectTransfer := TransferHeader."Direct Transfer";
        xLastShipmentNo := TransferHeader."Last Shipment No.";
        xLastReceiptNo := TransferHeader."Last Receipt No.";

        RequestJson := Argument.GetRequestJson();

        if DirectTransfer then begin
            // For direct transfers, BC decides ship+receive vs single Direct Transfer
            // based on Inventory Setup "Direct Transfer Posting".
            ResolveDirectTransferOptions(PostShipment, PostReceipt, PostTransfer);
            PostingTypeText := 'DirectTransfer';
        end else
            if RequestJson.Get('postingType', Token) then begin
                PostingTypeText := Token.AsValue().AsText();
                case LowerCase(PostingTypeText) of
                    'ship':
                        PostShipment := true;
                    'receive':
                        PostReceipt := true;
                    'shipreceive', 'ship+receive':
                        begin
                            // For non-direct transfers, ShipReceive isn't a native option.
                            // Caller should run Ship first, then Receive once goods arrive.
                            Argument.RespondWithError(StrSubstNo(InvalidPostingTypeErr, PostingTypeText));
                            exit;
                        end;
                    else begin
                        Argument.RespondWithError(StrSubstNo(InvalidPostingTypeErr, PostingTypeText));
                        exit;
                    end;
                end;
            end else begin
                Argument.RespondWithError(MissingPostingTypeErr);
                exit;
            end;

        // Configure and invoke the post codeunit. The subscriber overrides
        // OnBeforeGetPostingOptions to inject our PostShipment/PostReceipt/PostTransfer choices
        // and suppress the StrMenu prompt that GetPostingOptions otherwise raises.
        TransferHeader.SetHideValidationDialog(true);
        TransferPostSubscriber.SetChoices(PostShipment, PostReceipt, PostTransfer);
        BindSubscription(TransferPostSubscriber);
        Commit();
        if not TransferOrderPostYesNo.Run(TransferHeader) then begin
            UnbindSubscription(TransferPostSubscriber);
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        UnbindSubscription(TransferPostSubscriber);

        TransferHeader.Find();

        BuildSuccessResponse(TransferHeader, DocumentNo, PostingTypeText, xLastShipmentNo, xLastReceiptNo, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>
    /// For direct transfers, reads Inventory Setup "Direct Transfer Posting" and sets the
    /// posting flags accordingly: Receipt and Shipment yields both ship and receive; Direct Transfer
    /// yields the single-step transfer posting.
    /// </summary>
    local procedure ResolveDirectTransferOptions(var PostShipment: Boolean; var PostReceipt: Boolean; var PostTransfer: Boolean)
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.Get();
        case InventorySetup."Direct Transfer Posting" of
            InventorySetup."Direct Transfer Posting"::"Receipt and Shipment":
                begin
                    PostShipment := true;
                    PostReceipt := true;
                end;
            InventorySetup."Direct Transfer Posting"::"Direct Transfer":
                PostTransfer := true;
        end;
    end;

    local procedure BuildSuccessResponse(TransferHeader: Record "Transfer Header"; DocumentNo: Code[20]; PostingTypeText: Text; xLastShipmentNo: Code[20]; xLastReceiptNo: Code[20]; var ResponseJson: JsonObject)
    var
        PostedShipmentNo: Code[20];
        PostedReceiptNo: Code[20];
    begin
        if TransferHeader."Last Shipment No." <> xLastShipmentNo then
            PostedShipmentNo := TransferHeader."Last Shipment No.";
        if TransferHeader."Last Receipt No." <> xLastReceiptNo then
            PostedReceiptNo := TransferHeader."Last Receipt No.";

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('postingType', PostingTypeText);
        ResponseJson.Add('directTransfer', TransferHeader."Direct Transfer");
        ResponseJson.Add('postedShipmentNo', PostedShipmentNo);
        ResponseJson.Add('postedReceiptNo', PostedReceiptNo);
        ResponseJson.Add('postingDate', Format(TransferHeader."Posting Date", 0, 9));
    end;
}
