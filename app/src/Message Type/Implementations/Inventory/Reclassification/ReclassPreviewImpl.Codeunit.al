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
        WrongTypeErr: Label 'Journal template %1 is not a Transfer template.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 er ekki af gerðinni Transfer.';
        EmptyBatchErr: Label 'Reclassification batch %1 %2 has no lines.', Comment = '%1 = template, %2 = batch; is-IS=Endurflokkunarkeyrsla %1 %2 hefur engar línur.';
        BatchMissingErr: Label 'Reclassification journal template or batch was not found.', Comment = 'is-IS=Endurflokkunarbókarsniðmát eða keyrsla fannst ekki.';
        NextStepLbl: Label 'Choose an existing Transfer journal batch and correct its posting errors before retrying.', Comment = 'is-IS=Veldu fyrirliggjandi millifærslubókarkeyrslu og leiðréttu bókunarvillur áður en reynt er aftur.';
        JournalTemplate: Record "Item Journal Template";
        JournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        RequestJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        FailureJournal: Codeunit "Inventory Native Journal ori";
        NativeJournal: Codeunit "Inventory Native Journal ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        Process: Codeunit "Inventory Read Process ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        if not NativeJournal.AssertItemPostingPermission(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Contains('journalTemplateName') then
            TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalTemplateName', Argument, true, 10), 1, 10)
        else
            if RequestJson.Contains('templateName') then
                TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'templateName', Argument, true, 10), 1, 10)
            else
                TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalTemplateName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        if RequestJson.Contains('journalBatchName') then
            BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalBatchName', Argument, true, 10), 1, 10)
        else
            if RequestJson.Contains('batchName') then
                BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'batchName', Argument, true, 10), 1, 10)
            else
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
        if ItemJournalLine.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(EmptyBatchErr, TemplateName, BatchName), 'journalBatchName', BatchName, '', NextStepLbl);
            exit;
        end;
        Process.SetOperation('ReclassPreview');
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                FailureJournal.RespondWithFailure(Argument);
                exit;
            end;
        AddPreviewCompat(Argument);
    end;

    local procedure AddPreviewCompat(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        if not Response.Contains('templateName') then
            exit;
        if Response.Get('linesToPost', Token) and not Response.Contains('lineCount') then
            Response.Add('lineCount', Token.AsValue().AsInteger());
        if Response.Get('result', Token) and not Response.Contains('lines') then
            Response.Add('lines', Token);
        // Keep the published response schema: native-only keys are folded into lineCount and lines.
        Response.Remove('templateName');
        Response.Remove('batchName');
        Response.Remove('linesToPost');
        Response.Remove('result');
        Argument.SetResponseJson(Response);
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
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Item journal template name, at most 10 characters. The template must exist and have type Transfer. Required unless templateName is sent; journalTemplateName wins when both are sent.'));
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Alias of journalTemplateName, read only when journalTemplateName is absent.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Name of the journal batch whose posting is simulated, at most 10 characters. Required unless batchName is sent; journalBatchName wins when both are sent.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Alias of journalBatchName, read only when journalBatchName is absent.'));
        Parameters.Add(ContractMgt.Parameter('lineSystemIds', 'array', false, 'Optional nonempty array of distinct SystemIds of lines in the identified batch; only those lines are simulated. Without it every line of the batch is used.'));
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
        ErrorHelp1Lbl: Label 'The Reclassification domain is turned off for this company in Inventory Setup.', Comment = 'is-IS=Slökkt er á endurflokkun fyrir þetta fyrirtæki í birgðauppsetningu.';
        ErrorHelp2Lbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á aðgerðasviðinu á birgðauppsetningarsíðunni.';
        ErrorHelp3Lbl: Label 'The caller lacks Inv. Posting Gate. Native preview executes posting with rollback and retains the posting gate.', Comment = 'is-IS=Kallandi hefur ekki Bókunarhlið birgða. Bókunarforskoðun bakfærir breytingar og heldur bókunarheimildarskoðun virkri.';
        ErrorHelp4Lbl: Label 'Ask an administrator for the posting permission and required native permissions.', Comment = 'is-IS=Biddu stjórnanda um bókunarheimild og nauðsynlegar kerfisheimildir.';
        ErrorHelp5Lbl: Label 'journalTemplateName or journalBatchName is absent.', Comment = 'is-IS=journalTemplateName eða journalBatchName vantar.';
        ErrorHelp6Lbl: Label 'Supply both journal selectors.', Comment = 'is-IS=Tilgreindu bæði bókarsniðmát og keyrslu.';
        ErrorHelp7Lbl: Label 'The journal template or batch does not exist.', Comment = 'is-IS=Bókarsniðmátið eða keyrslan er ekki til.';
        ErrorHelp8Lbl: Label 'Choose an existing batch.', Comment = 'is-IS=Veldu fyrirliggjandi keyrslu.';
        ErrorHelp9Lbl: Label 'The template is not Transfer or the batch has no lines.', Comment = 'is-IS=Sniðmátið er ekki af gerðinni Transfer eða keyrslan hefur engar línur.';
        ErrorHelp10Lbl: Label 'Choose a nonempty reclassification batch.', Comment = 'is-IS=Veldu endurflokkunarkeyrslu með línum.';
        ErrorHelp11Lbl: Label 'Native posting preview refused a journal line.', Comment = 'is-IS=Bókunarforskoðun hafnaði bókarlínu.';
        ErrorHelp12Lbl: Label 'Correct the reported posting error and preview again.', Comment = 'is-IS=Leiðréttu tilgreinda bókunarvillu og forskoðaðu aftur.';
        ErrorHelp13Lbl: Label 'A journal selector is not JSON text.', Comment = 'is-IS=Bókarval er ekki JSON-texti.';
        ErrorHelp14Lbl: Label 'Send the documented selector as a JSON string.', Comment = 'is-IS=Sendu skjalfesta valbreytu sem JSON-streng.';
        ErrorHelp15Lbl: Label 'A journal selector exceeds 10 characters.', Comment = 'is-IS=Bókarval er lengra en 10 stafir.';
        ErrorHelp16Lbl: Label 'Use a journal template or batch name of at most 10 characters.', Comment = 'is-IS=Notaðu heiti bókarsniðmáts eða keyrslu með að hámarki 10 stöfum.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp1Lbl, ErrorHelp2Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorHelp3Lbl, ErrorHelp4Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp5Lbl, ErrorHelp6Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorHelp7Lbl, ErrorHelp8Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorHelp9Lbl, ErrorHelp10Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorHelp11Lbl, ErrorHelp12Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorHelp13Lbl, ErrorHelp14Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp15Lbl, ErrorHelp16Lbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Native posting is simulated and its ledger entries are captured. All simulated writes are rolled back; the journal and persisted ledger remain unchanged.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
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
            'Preview does not commit the caller transaction or persist journal, item, value or G/L entry changes. The posting permission Inv. Posting Gate and native posting permissions remain required because native posting is executed under rollback. ' +
            'Inventory.Reclassification.Check only reads the template and counts transfer lines; it needs read permission and does not predict all posting errors. Use PreviewPost before the separate Post operation.';
        exit(true);
    end;
}
