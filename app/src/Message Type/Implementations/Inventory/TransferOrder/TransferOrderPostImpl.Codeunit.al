namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013415 "Transfer Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        if not DomainGate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true) then
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
    var
        SelectionDescriptionLbl: Label 'Posts a transfer order by shipping or receiving it; use PreviewPost to inspect predicted entries first.', Comment = 'is-IS=Bókar millifærslupöntun með afhendingu eða móttöku; notaðu PreviewPost til að skoða væntanlegar færslur fyrst.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := Parts.GetParameters('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Related := Parts.GetRelated('Inventory.TransferOrder.Post');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.TransferOrder.Post');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := Parts.GetNotes('Inventory.TransferOrder.Post');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TransferHeader: Record "Transfer Header";
        DocumentLookup: Codeunit "Document Lookup ori";
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
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        if not DocumentLookup.FindTransferHeader(Argument, TransferHeader) then
            exit;

        DocumentNo := TransferHeader."No.";
        DirectTransfer := TransferHeader."Direct Transfer";
        xLastShipmentNo := TransferHeader."Last Shipment No.";
        xLastReceiptNo := TransferHeader."Last Receipt No.";
        RequestJson := Argument.GetRequestJson();

        if DirectTransfer then begin
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
