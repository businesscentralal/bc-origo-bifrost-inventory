namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reclassification.Post. Posts a reclassification journal batch through Item Jnl.-Post Batch.
/// </summary>
codeunit 10076888 "Reclass Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Posts an item reclassification journal. This is not a transfer order.', Comment = 'is-IS=Bókar endurflokkunarbók vöru. Þetta er ekki millifærslupöntun.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reclassification journal, post reclassification', Comment = 'is-IS=endurflokkunarbók, bóka endurflokkun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Posts a reclassification journal. Does not create a transfer order.', Comment = 'is-IS=Bókar endurflokkunarbók. Býr ekki til millifærslupöntun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalLine: Record "Item Journal Line";
        JournalTemplate: Record "Item Journal Template";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        MissingJournalErr: Label 'Journal template %1 was not found.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 fannst ekki.';
        WrongTypeErr: Label 'Journal template %1 is not a Transfer template.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 er ekki af gerðinni Transfer.';
        TransferExpectedLbl: Label 'an existing Transfer journal template', Comment = 'is-IS=fyrirliggjandi bókarsniðmát af gerðinni Transfer';
        TransferNextLbl: Label 'Use a reclassification journal template of type Transfer; use the dedicated posting type for other journals.', Comment = 'is-IS=Notaðu endurflokkunarbókarsniðmát af gerðinni Transfer; notaðu viðeigandi bókunartegund fyrir aðrar bækur.';
        BatchExpectedLbl: Label 'a nonempty Transfer journal batch that passes native posting', Comment = 'is-IS=millifærslubókarkeyrsla með línum sem stenst hefðbundna bókun';
        BatchNextLbl: Label 'Check the selected batch and correct the posting error before retrying.', Comment = 'is-IS=Athugaðu valda bókarkeyrslu og leiðréttu bókunarvilluna áður en reynt er aftur.';
        EmptyBatchErr: Label 'Reclassification batch %1 %2 has no lines.', Comment = '%1 = template, %2 = batch, is-IS=Endurflokkunarkeyrsla %1 %2 hefur engar línur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalTemplateName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalBatchName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        if not JournalTemplate.Get(TemplateName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingJournalErr, TemplateName), 'journalTemplateName', TemplateName, TransferExpectedLbl, TransferNextLbl);
            exit;
        end;
        if JournalTemplate.Type <> JournalTemplate.Type::Transfer then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(WrongTypeErr, TemplateName), 'journalTemplateName', TemplateName, TransferExpectedLbl, TransferNextLbl);
            exit;
        end;
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        if not ItemJournalLine.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(EmptyBatchErr, TemplateName, BatchName), 'journalBatchName', BatchName, BatchExpectedLbl, BatchNextLbl);
            exit;
        end;
        if not ItemJnlPostBatch.Run(ItemJournalLine) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'journalBatchName', BatchName, BatchExpectedLbl, BatchNextLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('journalTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
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
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, 'Item journal template name, at most 10 characters; read as an upper-case code. Use a reclassification template (type Transfer); other template types are refused before posting.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Name of the journal batch to post, at most 10 characters; read as an upper-case code. Every line of the batch is posted.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the batch was posted.'));
        Fields.Add(ContractMgt.ResponseField('journalTemplateName', 'string', 'The template that was posted, as read from the request.'));
        Fields.Add(ContractMgt.ResponseField('journalBatchName', 'string', 'The batch that was posted, as read from the request.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ErrorHelp1Lbl: Label 'The journal template does not exist.', Comment = 'is-IS=Bókarsniðmátið er ekki til.';
        ErrorHelp2Lbl: Label 'Send the name of an existing Transfer journal template.', Comment = 'is-IS=Sendu heiti fyrirliggjandi bókarsniðmáts af gerðinni Transfer.';
        ErrorHelp3Lbl: Label 'The journal template is not of type Transfer.', Comment = 'is-IS=Bókarsniðmátið er ekki af gerðinni Transfer.';
        ErrorHelp4Lbl: Label 'Use a reclassification template; use the dedicated posting message for other journal types.', Comment = 'is-IS=Notaðu endurflokkunarsniðmát; notaðu viðeigandi bókunarskilaboð fyrir aðrar bókargerðir.';
        ErrorHelp5Lbl: Label 'journalTemplateName is absent.', Comment = 'is-IS=journalTemplateName vantar.';
        ErrorHelp6Lbl: Label 'Send journalTemplateName.', Comment = 'is-IS=Sendu journalTemplateName.';
        ErrorHelp7Lbl: Label 'journalBatchName is absent.', Comment = 'is-IS=journalBatchName vantar.';
        ErrorHelp8Lbl: Label 'Send journalBatchName.', Comment = 'is-IS=Sendu journalBatchName.';
        ErrorHelp9Lbl: Label 'The Reclassification domain is turned off for this company in Inventory Setup.', Comment = 'is-IS=Slökkt er á endurflokkun fyrir þetta fyrirtæki í birgðauppsetningu.';
        ErrorHelp10Lbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á aðgerðasviðinu á birgðauppsetningarsíðunni.';
        ErrorHelp11Lbl: Label 'The caller lacks the posting permission set BIFROST InvPost ori.', Comment = 'is-IS=Kallandi hefur ekki bókunarheimildasafnið BIFROST InvPost ori.';
        ErrorHelp12Lbl: Label 'Ask an administrator for BIFROST InvPost ori.', Comment = 'is-IS=Biddu stjórnanda um BIFROST InvPost ori.';
        ErrorHelp13Lbl: Label 'The selected batch has no lines or native posting fails; native error text is preserved unchanged.', Comment = 'is-IS=Valin keyrsla hefur engar línur eða bókun mistekst; upprunaleg villuboð kerfisins haldast óbreytt.';
        ErrorHelp14Lbl: Label 'Check the selected batch and correct the posting error before retrying.', Comment = 'is-IS=Athugaðu valda bókarkeyrslu og leiðréttu bókunarvilluna áður en reynt er aftur.';
        ErrorHelp15Lbl: Label 'A journal selector is not JSON text.', Comment = 'is-IS=Bókarval er ekki JSON-texti.';
        ErrorHelp16Lbl: Label 'Send the documented selector as a JSON string.', Comment = 'is-IS=Sendu skjalfesta valbreytu sem JSON-streng.';
        ErrorHelp17Lbl: Label 'A journal selector exceeds 10 characters.', Comment = 'is-IS=Bókarval er lengra en 10 stafir.';
        ErrorHelp18Lbl: Label 'Use a journal template or batch name of at most 10 characters.', Comment = 'is-IS=Notaðu heiti bókarsniðmáts eða keyrslu með að hámarki 10 stöfum.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorHelp1Lbl, ErrorHelp2Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorHelp3Lbl, ErrorHelp4Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp5Lbl, ErrorHelp6Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp7Lbl, ErrorHelp8Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp9Lbl, ErrorHelp10Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorHelp11Lbl, ErrorHelp12Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorHelp13Lbl, ErrorHelp14Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorHelp15Lbl, ErrorHelp16Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp17Lbl, ErrorHelp18Lbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Posts every line of the item journal batch through the standard item journal batch posting: item ledger and value entries are created, an item register is written and the posted lines leave the journal. The posting commits. It does not create or post a transfer order.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori and BIFROST InvPost ori');
        Effect.Add('writes', true);
        Effect.Add('posts', true);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reclassification.Check', 'Use it first to confirm that the template is a reclassification template.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reclassification.PreviewPost', 'Use it first to list the lines that the posting would process.'));
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
            'Post the reclassification batch DEFAULT',
            '{"type":"Inventory.Reclassification.Post","data":{"journalTemplateName":"RECLASS","journalBatchName":"DEFAULT"}}',
            '{"status":"Success","journalTemplateName":"RECLASS","journalBatchName":"DEFAULT"}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Posts every line of a reclassification journal batch through the standard item journal batch posting. Posting is permanent and needs the BIFROST InvPost ori permission set.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Posting is permanent and commits. All lines of the batch are posted; the call has no line selection. It does not create or post a transfer order. ' +
            'The call requires an existing reclassification (Transfer) template before it reads or posts any journal line. Missing templates return RecordNotFound; other template types return PreconditionFailed with a nextStep. ' +
            'A batch without lines, or one that does not exist, returns PreconditionFailed. A posting error returns PreconditionFailed with Business Central''s unchanged text and the selected batch; posting is rolled back. ' +
            'The caller needs the BIFROST InvPost ori permission set (without it the call is not listed as enabled) and the table permissions that the standard item journal posting itself needs. The Reclassification domain must be turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.Reclassification.Check first. Inventory.Reclassification.PreviewPost runs native posting preview, returns captured ledger entries and rolls back the simulated posting changes.';
        exit(true);
    end;
}
