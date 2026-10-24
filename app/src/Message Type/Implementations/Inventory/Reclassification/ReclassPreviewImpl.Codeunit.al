namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Foundation.Navigate;
using Origo.Bifrost;

codeunit 10076889 "Reclass Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Simulates posting a reclassification journal batch and returns the captured ledger entries. All posting changes are rolled back.', Comment = 'is-IS=Líkir eftir bókun endurflokkunarbókarkeyrslu og skilar færslunum. Öllum bókunarbreytingum er velt til baka.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview reclassification, reclass journal preview', Comment = 'is-IS=forskoða endurflokkun, forskoðun endurflokkunarbókar';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Previews the ledger entries of one Transfer journal batch without saving posting changes.', Comment = 'is-IS=Forskoðar færslur einnar millifærslubókarkeyrslu án þess að vista bókunarbreytingar.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalLine: Record "Item Journal Line";
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        LineJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        WrongTypeErr: Label 'Journal template %1 is not a Transfer template.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 er ekki af gerðinni Transfer.';
        EmptyBatchErr: Label 'Reclassification batch %1 %2 has no lines.', Comment = '%1 = template, %2 = batch; is-IS=Endurflokkunarkeyrsla %1 %2 hefur engar línur.';
        BatchMissingErr: Label 'Reclassification journal template or batch was not found.', Comment = 'is-IS=Endurflokkunarbókarsniðmát eða keyrsla fannst ekki.';
        NextStepLbl: Label 'Choose an existing Transfer journal batch and correct its posting errors before retrying.', Comment = 'is-IS=Veldu fyrirliggjandi millifærslubókarkeyrslu og leiðréttu bókunarvillur áður en reynt er aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalTemplateName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalBatchName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;

        if not JournalTemplate.Get(TemplateName) or not JournalBatch.Get(TemplateName, BatchName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, BatchMissingErr, 'journalBatchName', BatchName, '', NextStepLbl);
            exit;
        end;
        if JournalTemplate.Type <> JournalTemplate.Type::Transfer then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(WrongTypeErr, TemplateName), 'journalTemplateName', TemplateName, 'Transfer', NextStepLbl);
            exit;
        end;
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        if ItemJournalLine.FindSet() then
            repeat
                Clear(LineJson);
                LineJson.Add('lineNo', ItemJournalLine."Line No.");
                LineJson.Add('itemNo', ItemJournalLine."Item No.");
                LineJson.Add('quantity', ItemJournalLine.Quantity);
                LineJson.Add('locationCode', ItemJournalLine."Location Code");
                LineJson.Add('newLocationCode', ItemJournalLine."New Location Code");
                Lines.Add(LineJson);
                LineCount += 1;
            until ItemJournalLine.Next() = 0;

        if LineCount = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(EmptyBatchErr, TemplateName, BatchName), 'journalBatchName', BatchName, '', NextStepLbl);
            exit;
        end;
        ItemJournalLine.FindFirst();
        if not PreviewEntries(Argument, ItemJournalLine, ResponseJson) then
            exit;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('rollback', true);
        ResponseJson.Add('lineCount', LineCount);
        ResponseJson.Add('lines', Lines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure PreviewEntries(var Argument: Record "Message Argument ori"; var Line: Record "Item Journal Line"; var Response: JsonObject): Boolean
    var
        TempDocumentEntry: Record "Document Entry" temporary;
        NativePreview: Codeunit "Gen. Jnl.-Post Preview";
        ItemPost: Codeunit "Item Jnl.-Post";
        Handler: Codeunit "Posting Preview Event Handler";
        PreviewHelper: Codeunit "Posting Preview Helper ori";
        Fields: List of [Text];
        Entries: JsonArray;
        Totals: JsonObject;
        EntryCount: Integer;
        GLEntryCount: Integer;
        Balanced: Boolean;
        NextStepLbl: Label 'Correct the reclassification journal posting errors and run the preview again.', Comment = 'is-IS=Leiðréttu bókunarvillur endurflokkunarbókar og keyrðu forskoðun aftur.';
    begin
        // Native preview owns the rollback boundary. Never commit the caller's transaction here.
        ClearLastError();
        BindSubscription(ItemPost);
        NativePreview.SetContext(ItemPost, Line);
        if NativePreview.Run() then;
        UnbindSubscription(ItemPost);
        if not NativePreview.IsSuccess() then begin
            PreviewHelper.RespondWithPreviewError(Argument, GetLastErrorText(), NextStepLbl);
            exit(false);
        end;
        NativePreview.GetPreviewHandler(Handler);
        PreviewHelper.GetPreviewFieldNames(Fields);
        Handler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PreviewHelper.AddTableToPreview(Entries, Handler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", Fields);
            until TempDocumentEntry.Next() = 0;
        if not PreviewHelper.EvaluatePreviewOutcome(Argument, Entries, Handler, NextStepLbl, Totals, Balanced, EntryCount, GLEntryCount) then
            exit(false);
        Response.Add('preview', Entries);
        Response.Add('totals', Totals);
        PreviewHelper.AddEntryCounts(Response, EntryCount, GLEntryCount);
        exit(true);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"No subject is used; the template and the batch are sent in data."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.journalTemplateName, data.journalBatchName', 'journal template and batch name', 'The item journal template and batch that hold the reclassification lines.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, 'Item journal template name, at most 10 characters. The template must exist and have type Transfer.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Name of the journal batch whose posting is simulated, at most 10 characters.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Field: JsonObject;
        Fields: JsonArray;
        Children: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when native posting preview captured ledger entries.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'True after native preview rolls back all simulated posting changes.'));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of lines in the existing nonempty batch.'));
        Field := ContractMgt.ResponseField('lines', 'array', 'Every line of the batch.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number in the batch.'));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number of the line.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Quantity of the line.'));
        Children.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code of the line.'));
        Children.Add(ContractMgt.ResponseField('newLocationCode', 'string', 'New location code of the line.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Ledger entries captured by native posting preview.'));
        Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Captured debit, credit and net G/L totals.'));
        Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total captured ledger entries.'));
        Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Captured G/L entries.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Reclassification domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks BIFROST InvPost ori. Native preview executes posting with rollback and retains the posting gate.', 'Ask an administrator for the posting permission and required native permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'journalTemplateName or journalBatchName is absent.', 'Supply both journal selectors.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The journal template or batch does not exist.', 'Choose an existing batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The template is not Transfer or the batch has no lines.', 'Choose a nonempty reclassification batch.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native posting preview refused a journal line.', 'Correct the reported posting error and preview again.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A journal selector is not JSON text.', 'Send the documented selector as a JSON string.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A journal selector exceeds 10 characters.', 'Use a journal template or batch name of at most 10 characters.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Native posting is simulated and its ledger entries are captured. All simulated writes are rolled back; the journal and persisted ledger remain unchanged.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori and BIFROST InvPost ori');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reclassification.Check', 'Use it to confirm that the template is a reclassification template.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reclassification.Post', 'Use it to post the reclassification batch.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reclassification.Check', 'Confirm that the template is a reclassification template and see how many transfer lines the batch has.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reclassification.PreviewPost', 'Simulate native posting and inspect the rolled-back ledger entries.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reclassification.Post', 'Post the batch; the lines are written to the item ledger.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Preview posting of the reclassification batch DEFAULT',
            '{"type":"Inventory.Reclassification.PreviewPost","data":{"journalTemplateName":"RECLASS","journalBatchName":"DEFAULT"}}',
            '{"status":"Success","rollback":true,"lineCount":1,"lines":[{"lineNo":10000,"itemNo":"1000","quantity":5,"locationCode":"BLUE","newLocationCode":"RED"}],"preview":[{"tableId":32,"entryCount":2,"entries":[]}],"totals":{"totalDebitLCY":0,"totalCreditLCY":0},"entryCount":2,"glEntryCount":0}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Simulates native posting of a Transfer journal batch, returns captured ledger entries and rolls back all posting changes.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Runs native posting preview for one existing nonempty Transfer journal batch. Posting validation errors are returned instead of a successful line listing. ' +
            'Successful answers retain lineCount and lines and add preview, totals, entryCount and glEntryCount from captured entries. rollback is true only after native preview succeeds. ' +
            'Preview does not commit the caller transaction or persist journal, item, value or G/L entry changes. The posting permission BIFROST InvPost ori and native posting permissions remain required because native posting is executed under rollback. ' +
            'Inventory.Reclassification.Check only reads the template and counts transfer lines; it needs read permission and does not predict all posting errors. Use PreviewPost before the separate Post operation.';
        exit(true);
    end;
}
