namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 10076903 "Transfer Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Posts a transfer order (ship/receive, or ship+receive for direct transfers).', Comment = 'is-IS=Bókar millifærslupöntun (afhendingu eða móttöku, eða hvort tveggja við beina millifærslu).';
    begin
        exit(DescriptionLbl);
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
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Workflow := Parts.GetWorkflow('Inventory.TransferOrder.Post');
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Examples := Parts.GetExamples('Inventory.TransferOrder.Post');
        exit(Examples.Count() > 0);
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
        TransferHeader: Record "Transfer Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        DocumentLookup: Codeunit "Document Lookup ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        TransferOrderPostYesNo: Codeunit "TransferOrder-Post (Yes/No)";
        TransferPostSubscriber: Codeunit "Transfer Post Subscriber ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PostingTypeText: Text;
        PostingTypeNormalized: Text;
        DocumentNo: Code[20];
        DirectTransfer: Boolean;
        PostShipment: Boolean;
        PostReceipt: Boolean;
        PostTransfer: Boolean;
        PostingExpectedTxt: Label 'Ship or Receive for a non-direct transfer order.', Comment = 'is-IS=Ship eða Receive fyrir flutningspöntun sem er ekki bein.';
        PostingNextStepTxt: Label 'Send postingType="Ship" or postingType="Receive" for the selected transfer order.', Comment = 'is-IS=Sendu postingType="Ship" eða postingType="Receive" fyrir valda flutningspöntun.';
        NativeExpectedTxt: Label 'A transfer order that passes native posting validation.', Comment = 'is-IS=Flutningspöntun sem stenst innbyggða bókunarprófun.';
        NativeNextStepTxt: Label 'Correct the selected document and inspect its posted state before retrying.', Comment = 'is-IS=Leiðréttu valda skjalið og skoðaðu bókaða stöðu þess áður en þú reynir aftur.';
        MissingPostingTypeErr: Label 'For a non-direct transfer order, postingType must be "Ship" or "Receive".', Comment = 'is-IS=Fyrir millifærslupöntun sem er ekki bein verður postingType að vera "Ship" eða "Receive".';
        InvalidPostingTypeErr: Label 'postingType must be "Ship" or "Receive". Received: %1', Comment = '%1 = received value, is-IS=postingType verður að vera "Ship" eða "Receive". Móttekið: %1';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        RequestJson := Argument.GetRequestJson();
        PostingTypeText := Parts.ReadRequestText(Argument, RequestJson, 'postingType', false, 30);
        if Parts.RespondToProblems(Argument) then
            exit;
        if not DocumentLookup.FindTransferHeader(Argument, TransferHeader) then
            exit;

        DocumentNo := TransferHeader."No.";
        DirectTransfer := TransferHeader."Direct Transfer";
        RequestJson := Argument.GetRequestJson();

        if DirectTransfer then begin
            ResolveDirectTransferOptions(PostShipment, PostReceipt, PostTransfer);
            PostingTypeText := 'DirectTransfer';
        end else
            if PostingTypeText <> '' then begin
                PostingTypeNormalized := LowerCase(PostingTypeText);
                case PostingTypeNormalized of
                    'ship':
                        PostShipment := true;
                    'receive':
                        PostReceipt := true;
                    'shipreceive', 'ship+receive':
                        begin
                            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidPostingTypeErr, PostingTypeText), 'postingType', PostingTypeText, PostingExpectedTxt, PostingNextStepTxt);
                            exit;
                        end;
                    else begin
                        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidPostingTypeErr, PostingTypeText), 'postingType', PostingTypeText, PostingExpectedTxt, PostingNextStepTxt);
                        exit;
                    end;
                end;
            end else begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingPostingTypeErr, 'postingType', '<missing>', PostingExpectedTxt, PostingNextStepTxt);
                exit;
            end;

        TransferHeader.SetHideValidationDialog(true);
        TransferPostSubscriber.SetChoices(PostShipment, PostReceipt, PostTransfer);
        BindSubscription(TransferPostSubscriber);
        Commit();
        if not TransferOrderPostYesNo.Run(TransferHeader) then begin
            UnbindSubscription(TransferPostSubscriber);
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'documentNo', DocumentNo, NativeExpectedTxt, NativeNextStepTxt);
            exit;
        end;
        UnbindSubscription(TransferPostSubscriber);

        // A full receive (or a direct transfer) deletes the order, so the posted numbers come from the
        // bound subscriber rather than from the order header.
        BuildSuccessResponse(TransferPostSubscriber, DocumentNo, PostingTypeText, DirectTransfer, ResponseJson);
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

    local procedure BuildSuccessResponse(var TransferPostSubscriber: Codeunit "Transfer Post Subscriber ori"; DocumentNo: Code[20]; PostingTypeText: Text; DirectTransfer: Boolean; var ResponseJson: JsonObject)
    var
        TransferHeader: Record "Transfer Header";
        PostingDate: Date;
        OrderExists: Boolean;
    begin
        TransferHeader.SetLoadFields("Posting Date");
        OrderExists := TransferHeader.Get(DocumentNo);
        PostingDate := TransferPostSubscriber.GetPostingDate();
        if (PostingDate = 0D) and OrderExists then
            PostingDate := TransferHeader."Posting Date";
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('postingType', PostingTypeText);
        ResponseJson.Add('directTransfer', DirectTransfer);
        ResponseJson.Add('postedShipmentNo', TransferPostSubscriber.GetPostedShipmentNo());
        ResponseJson.Add('postedReceiptNo', TransferPostSubscriber.GetPostedReceiptNo());
        ResponseJson.Add('orderDeleted', not OrderExists);
        ResponseJson.Add('postingDate', Format(PostingDate, 0, 9));
    end;
}
