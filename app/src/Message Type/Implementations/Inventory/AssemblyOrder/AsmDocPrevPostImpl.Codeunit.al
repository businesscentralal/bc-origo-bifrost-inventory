namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.PreviewPost message type.
/// Simulates posting an assembly order and returns the captured ledger entries
/// (Item Ledger, Value Entry, G/L Entry, Resource Ledger where applicable) without
/// committing changes. The transaction is rolled back after capturing the simulated
/// entries via the Posting Preview Event Handler.
/// </summary>

using Microsoft.Assembly.Document;
using Microsoft.Assembly.Posting;
using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

codeunit 70013423 "Asm. Doc Prev. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Simulates posting an assembly order and returns predicted ledger entries (Item, Value, G/L, Resource) without committing changes.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview assembly posting, simulate assembly, what would the assembly post', Comment = 'is-IS=forskoða bókun samsetningar, herma samsetningu, hvað myndi samsetningin bóka';
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
        HelpCodeunit: Codeunit "Asm. Doc Prev. Post Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        GLSetup: Record "General Ledger Setup";
        TempDocumentEntry: Record "Document Entry" temporary;
        PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler";
        PreviewHelper: Codeunit "Preview Helper ori";
        ResponseJson: JsonObject;
        TotalsJson: JsonObject;
        PredictedJson: JsonObject;
        PreviewArray: JsonArray;
        DocumentNo: Code[20];
        LCYCode: Code[10];
        EntryCount: Integer;
        GLEntryCount: Integer;
        Balanced: Boolean;
        Summary: Text;
        PreviewErrorText: Text;
        PreviewFieldNames: List of [Text];
        NoLinesToPostErr: Label 'Assembly order %1 has no lines to post.', Comment = '%1 = Document No., is-IS=Samsetningarpöntun %1 hefur engar línur til að bóka.';
        PreviewFailedErr: Label 'Posting preview failed and no entries were captured. The assembly order cannot be posted in its current state.', Comment = 'is-IS=Bókunarforsýning mistókst og engar færslur voru teknar. Samsetningarpöntunin getur ekki verið bókuð í núverandi stöðu.';
        NothingToPostNextStepTok: Label 'Quantity to Assemble is 0. Review with Inventory.AssemblyOrder.Statistics.', Comment = 'is-IS=Magn til samsetningar er 0. Skoðið með Inventory.AssemblyOrder.Statistics.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        if AssemblyLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::NothingToPreview, StrSubstNo(NoLinesToPostErr, AssemblyHeader."No."), '', '', '', NothingToPostNextStepTok);
            exit;
        end;

        DocumentNo := AssemblyHeader."No.";

        GLSetup.Get();
        LCYCode := GLSetup."LCY Code";

        if not PreviewAssemblyOrder(AssemblyHeader, PostingPreviewEventHandler, PreviewErrorText) then begin
            if PreviewErrorText = '' then
                PreviewErrorText := PreviewFailedErr;
            PreviewHelper.RespondWithPreviewError(Argument, PreviewErrorText, NothingToPostNextStepTok);
            exit;
        end;

        PreviewHelper.GetPreviewFieldNames(PreviewFieldNames);

        PostingPreviewEventHandler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PreviewHelper.AddTableToPreview(PreviewArray, PostingPreviewEventHandler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", PreviewFieldNames);
            until TempDocumentEntry.Next() = 0;

        if not PreviewHelper.EvaluatePreviewOutcome(Argument, PreviewArray, PostingPreviewEventHandler, NothingToPostNextStepTok, TotalsJson, Balanced, EntryCount, GLEntryCount) then

            exit;

        BuildPredictedNumbers(PredictedJson, PostingPreviewEventHandler);

        Summary := BuildSummary(DocumentNo, AssemblyHeader."Item No.", PreviewArray, PreviewHelper.GLStatusSentence(GLEntryCount, Balanced));

        ResponseJson.Add('status', 'Success');
        PreviewHelper.AddEntryCounts(ResponseJson, EntryCount, GLEntryCount);
        ResponseJson.Add('rollback', true);
        ResponseJson.Add('summary', Summary);
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('locationCode', AssemblyHeader."Location Code");
        ResponseJson.Add('quantityToAssemble', AssemblyHeader."Quantity to Assemble");
        ResponseJson.Add('lcyCode', LCYCode);
        ResponseJson.Add('predictedNumbers', PredictedJson);
        ResponseJson.Add('totals', TotalsJson);
        ResponseJson.Add('preview', PreviewArray);

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildPredictedNumbers(var PredictedJson: JsonObject; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        TempRecRef: RecordRef;
        PostedAssemblyNo: Code[20];
    begin
        PostedAssemblyNo := '';
        TempRecRef.Open(Database::"Item Ledger Entry", true);
        PostingPreviewEventHandler.GetEntries(Database::"Item Ledger Entry", TempRecRef);
        if TempRecRef.FindSet() then
            repeat
                TempRecRef.SetTable(ItemLedgerEntry);
                if ItemLedgerEntry."Entry Type" = ItemLedgerEntry."Entry Type"::"Assembly Output" then
                    if PostedAssemblyNo = '' then
                        PostedAssemblyNo := ItemLedgerEntry."Document No.";
            until TempRecRef.Next() = 0;
        TempRecRef.Close();

        PredictedJson.Add('postedAssemblyNo', PostedAssemblyNo);
    end;

    local procedure BuildSummary(DocumentNo: Code[20]; ItemNo: Code[20]; var PreviewArray: JsonArray; GLStatusText: Text): Text
    var
        PreviewHelper: Codeunit "Preview Helper ori";
        Summary: Text;
        SummaryTok: Label 'Assembly Order %1 (Item %2) preview produced %3 entries. %4', Comment = '%1=Document No., %2=Item No., %3=entry count, %4=G/L status sentence', Locked = true;
    begin
        Summary := StrSubstNo(SummaryTok, DocumentNo, ItemNo, PreviewHelper.CountPreviewEntries(PreviewArray), GLStatusText);
        exit(Summary);
    end;

    /// <summary>
    /// Runs the BC built-in posting preview for an assembly order and returns the
    /// Posting Preview Event Handler containing the captured (rolled-back) ledger entries.
    /// Uses Gen. Jnl.-Post Preview's headless SetContext+Run() entry point so the caller
    /// can consume the captured entries instead of presenting them in the standard
    /// preview pages.
    /// </summary>
    local procedure PreviewAssemblyOrder(var AssemblyHeader: Record "Assembly Header"; var PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler"; var ErrorText: Text): Boolean
    var
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        AssemblyPostYesNo: Codeunit "Assembly-Post (Yes/No)";
    begin
        AssemblyHeader.SetHideValidationDialog(true);
        BindSubscription(AssemblyPostYesNo);
        GenJnlPostPreview.SetContext(AssemblyPostYesNo, AssemblyHeader);
        if GenJnlPostPreview.Run() then; // expected to throw Error('') after capturing entries
        UnbindSubscription(AssemblyPostYesNo);

        if not GenJnlPostPreview.IsSuccess() then begin
            ErrorText := GetLastErrorText();
            exit(false);
        end;

        GenJnlPostPreview.GetPreviewHandler(PostingPreviewEventHandler);
        exit(true);
    end;
}
