namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013413 "Transf Doc Prev. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true));
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Simulates posting a transfer order and returns predicted ledger entries (Item, Value, G/L) without committing changes.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview transfer posting, simulate stock transfer, what would the transfer post', Comment = 'is-IS=forskoða bókun millifærslu, herma birgðaflutning, hvað myndi millifærslan bóka';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Previews transfer posting without committing; use Post to perform the irreversible shipment or receipt.', Comment = 'is-IS=Forskoðar bókun millifærslu án frágangs; notaðu Post til að framkvæma óafturkræfa afhendingu eða móttöku.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := Parts.GetParameters('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.TransferOrder.PreviewPost');
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
        Related := Parts.GetRelated('Inventory.TransferOrder.PreviewPost');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Workflow := Parts.GetWorkflow('Inventory.TransferOrder.PreviewPost');
        exit(Workflow.Keys().Count() > 0);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.TransferOrder.PreviewPost');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := Parts.GetNotes('Inventory.TransferOrder.PreviewPost');
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
        TransferLine: Record "Transfer Line";
        GLSetup: Record "General Ledger Setup";
        TempDocumentEntry: Record "Document Entry" temporary;
        DocumentLookup: Codeunit "Document Lookup ori";
        PostingPreviewHelper: Codeunit "Posting Preview Helper ori";
        PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler";
        ResponseJson: JsonObject;
        TotalsJson: JsonObject;
        PredictedJson: JsonObject;
        PreviewArray: JsonArray;
        RequestJson: JsonObject;
        Token: JsonToken;
        PostingType: Enum "Transfer Order Post";
        PostingTypeText: Text;
        DocumentNo: Code[20];
        DirectTransfer: Boolean;
        PostShipment: Boolean;
        PostReceipt: Boolean;
        PostTransfer: Boolean;
        LCYCode: Code[10];
        EntryCount: Integer;
        GLEntryCount: Integer;
        Balanced: Boolean;
        Summary: Text;
        PreviewErrorText: Text;
        PreviewFieldNames: List of [Text];
        NoLinesToPostErr: Label 'Transfer order %1 has no lines to post.', Comment = '%1 = Document No., is-IS=Millifærslupöntun %1 hefur engar línur til að bóka.';
        PreviewFailedErr: Label 'Posting preview failed and no entries were captured. The transfer order cannot be posted in its current state.', Comment = 'is-IS=Bókunarforsýning mistókst og engar færslur voru teknar. Millifærslupöntunin getur ekki verið bókuð í núverandi stöðu.';
        MissingPostingTypeErr: Label 'For a non-direct transfer order, postingType must be "Ship" or "Receive".', Locked = true;
        InvalidPostingTypeErr: Label 'postingType must be "Ship" or "Receive". Received: %1', Comment = '%1 = received value', Locked = true;
        NothingToPostNextStepTok: Label 'No line has a quantity to ship or receive. Review with Inventory.TransferOrder.Statistics.', Comment = 'is-IS=Engin lína hefur magn til að senda eða móttaka. Skoðið með Inventory.TransferOrder.Statistics.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DocumentLookup.FindTransferHeader(Argument, TransferHeader) then
            exit;
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        if TransferLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::NothingToPreview, StrSubstNo(NoLinesToPostErr, TransferHeader."No."), '', '', '', NothingToPostNextStepTok);
            exit;
        end;
        DocumentNo := TransferHeader."No.";
        DirectTransfer := TransferHeader."Direct Transfer";
        RequestJson := Argument.GetRequestJson();
        if DirectTransfer then begin
            ResolveDirectTransferOptions(PostShipment, PostReceipt, PostTransfer);
            PostingTypeText := 'DirectTransfer';
        end else
            if RequestJson.Get('postingType', Token) then begin
                PostingTypeText := Token.AsValue().AsText();
                case LowerCase(PostingTypeText) of
                    'ship':
                        begin
                            PostShipment := true;
                            PostingType := PostingType::Ship;
                        end;
                    'receive':
                        begin
                            PostReceipt := true;
                            PostingType := PostingType::Receive;
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
        GLSetup.Get();
        LCYCode := GLSetup."LCY Code";
        if not PreviewTransferOrder(TransferHeader, PostShipment, PostReceipt, PostTransfer, PostingPreviewEventHandler, PreviewErrorText) then begin
            if PreviewErrorText = '' then
                PreviewErrorText := PreviewFailedErr;
            PostingPreviewHelper.RespondWithPreviewError(Argument, PreviewErrorText, NothingToPostNextStepTok);
            exit;
        end;
        PostingPreviewHelper.GetPreviewFieldNames(PreviewFieldNames);
        PostingPreviewEventHandler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PostingPreviewHelper.AddTableToPreview(PreviewArray, PostingPreviewEventHandler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", PreviewFieldNames);
            until TempDocumentEntry.Next() = 0;
        if not PostingPreviewHelper.EvaluatePreviewOutcome(Argument, PreviewArray, PostingPreviewEventHandler, NothingToPostNextStepTok, TotalsJson, Balanced, EntryCount, GLEntryCount) then
            exit;
        BuildPredictedNumbers(PredictedJson, PostingPreviewEventHandler, DirectTransfer, PostingType);
        Summary := BuildSummary(DocumentNo, TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Code", PostingTypeText, PreviewArray, PostingPreviewHelper.GLStatusSentence(GLEntryCount, Balanced));
        ResponseJson.Add('status', 'Success');
        PostingPreviewHelper.AddEntryCounts(ResponseJson, EntryCount, GLEntryCount);
        ResponseJson.Add('rollback', true);
        ResponseJson.Add('summary', Summary);
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('transferFromCode', TransferHeader."Transfer-from Code");
        ResponseJson.Add('transferToCode', TransferHeader."Transfer-to Code");
        ResponseJson.Add('directTransfer', DirectTransfer);
        ResponseJson.Add('postingType', PostingTypeText);
        ResponseJson.Add('lcyCode', LCYCode);
        ResponseJson.Add('predictedNumbers', PredictedJson);
        ResponseJson.Add('totals', TotalsJson);
        ResponseJson.Add('preview', PreviewArray);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildPredictedNumbers(var PredictedJson: JsonObject; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler"; DirectTransfer: Boolean; PostingType: Enum "Transfer Order Post")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        TempRecRef: RecordRef;
        ShipmentNo: Code[20];
        ReceiptNo: Code[20];
        DirectTransferNo: Code[20];
    begin
        ShipmentNo := '';
        ReceiptNo := '';
        DirectTransferNo := '';
        TempRecRef.Open(Database::"Item Ledger Entry", true);
        PostingPreviewEventHandler.GetEntries(Database::"Item Ledger Entry", TempRecRef);
        if TempRecRef.FindSet() then
            repeat
                TempRecRef.SetTable(ItemLedgerEntry);
                case ItemLedgerEntry."Entry Type" of
                    ItemLedgerEntry."Entry Type"::Transfer:
                        if DirectTransfer then begin
                            if DirectTransferNo = '' then
                                DirectTransferNo := ItemLedgerEntry."Document No.";
                        end else
                            if ItemLedgerEntry.Quantity < 0 then begin
                                if ShipmentNo = '' then
                                    ShipmentNo := ItemLedgerEntry."Document No.";
                            end else
                                if ReceiptNo = '' then
                                    ReceiptNo := ItemLedgerEntry."Document No.";
                end;
            until TempRecRef.Next() = 0;
        TempRecRef.Close();
        if DirectTransfer then
            PredictedJson.Add('postedDirectTransferNo', DirectTransferNo)
        else
            case PostingType of
                PostingType::Ship:
                    PredictedJson.Add('postedShipmentNo', ShipmentNo);
                PostingType::Receive:
                    PredictedJson.Add('postedReceiptNo', ReceiptNo);
            end;
    end;

    local procedure BuildSummary(DocumentNo: Code[20]; FromCode: Code[10]; ToCode: Code[10]; PostingTypeText: Text; var PreviewArray: JsonArray; GLStatusText: Text): Text
    var
        PostingPreviewHelper: Codeunit "Posting Preview Helper ori";
        SummaryTok: Label 'Transfer Order %1 (%2 -> %3) %4 preview produced %5 entries. %6', Comment = '%1=Document No., %2=From Code, %3=To Code, %4=Posting Type, %5=entry count, %6=G/L status sentence', Locked = true;
    begin
        exit(StrSubstNo(SummaryTok, DocumentNo, FromCode, ToCode, PostingTypeText, PostingPreviewHelper.CountPreviewEntries(PreviewArray), GLStatusText));
    end;

    local procedure PreviewTransferOrder(var TransferHeader: Record "Transfer Header"; PostShipment: Boolean; PostReceipt: Boolean; PostTransfer: Boolean; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler"; var ErrorText: Text): Boolean
    var
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        TransferOrderPostYesNo: Codeunit "TransferOrder-Post (Yes/No)";
        TransferPostSubscriber: Codeunit "Transfer Post Subscriber ori";
    begin
        TransferHeader.SetHideValidationDialog(true);
        TransferPostSubscriber.SetChoices(PostShipment, PostReceipt, PostTransfer);
        BindSubscription(TransferPostSubscriber);
        BindSubscription(TransferOrderPostYesNo);
        GenJnlPostPreview.SetContext(TransferOrderPostYesNo, TransferHeader);
        if GenJnlPostPreview.Run() then;
        UnbindSubscription(TransferOrderPostYesNo);
        UnbindSubscription(TransferPostSubscriber);
        if not GenJnlPostPreview.IsSuccess() then begin
            ErrorText := GetLastErrorText();
            exit(false);
        end;
        GenJnlPostPreview.GetPreviewHandler(PostingPreviewEventHandler);
        exit(true);
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
}
