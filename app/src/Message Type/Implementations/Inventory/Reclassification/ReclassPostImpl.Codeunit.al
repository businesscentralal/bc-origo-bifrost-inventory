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
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        MissingTemplateErr: Label 'journalTemplateName is required.', Comment = 'is-IS=journalTemplateName er nauðsynlegt.';
        MissingBatchErr: Label 'journalBatchName is required.', Comment = 'is-IS=journalBatchName er nauðsynlegt.';
        MissingJournalErr: Label 'Journal template %1 was not found.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 fannst ekki.';
        WrongTypeErr: Label 'Journal template %1 is not a Transfer template.', Comment = '%1 = template name; is-IS=Bókarsniðmátið %1 er ekki af gerðinni Transfer.';
        TransferExpectedLbl: Label 'an existing Transfer journal template', Comment = 'is-IS=fyrirliggjandi bókarsniðmát af gerðinni Transfer';
        TransferNextLbl: Label 'Use a reclassification journal template of type Transfer; use the dedicated posting type for other journals.', Comment = 'is-IS=Notaðu endurflokkunarbókarsniðmát af gerðinni Transfer; notaðu viðeigandi bókunartegund fyrir aðrar bækur.';
        EmptyBatchErr: Label 'Reclassification batch %1 %2 has no lines.', Comment = '%1 = template, %2 = batch, is-IS=Endurflokkunarkeyrsla %1 %2 hefur engar línur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTemplateErr, 'journalTemplateName', '', '', '');
            exit;
        end;
        TemplateName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingBatchErr, 'journalBatchName', '', '', '');
            exit;
        end;
        BatchName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(BatchName));
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
            Argument.RespondWithError(StrSubstNo(EmptyBatchErr, TemplateName, BatchName));
            exit;
        end;
        if not ItemJnlPostBatch.Run(ItemJournalLine) then begin
            Argument.RespondWithError(GetLastErrorText());
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
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The journal template does not exist.', 'Send the name of an existing Transfer journal template.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The journal template is not of type Transfer.', 'Use a reclassification template; use the dedicated posting message for other journal types.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'journalTemplateName is absent.', 'Send journalTemplateName.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'journalBatchName is absent.', 'Send journalBatchName.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Reclassification domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the posting permission set BIFROST InvPost ori.', 'Ask an administrator for BIFROST InvPost ori.'));
        Errors.Add(ContractMgt.TextErrorEntry('Reclassification batch %1 %2 has no lines.', 'The batch has no lines or does not exist. The answer carries the error text and no code.', 'Check journalTemplateName and journalBatchName, or create the lines first.'));
        Errors.Add(ContractMgt.TextErrorEntry('Business Central posting error text', 'The batch posting fails, for example because a line fails the item journal checks. The posting is rolled back and the answer carries the error text and no code.', 'Correct the line named in the text and retry.'));
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
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reclassification.PreviewPost', 'List the lines the posting would process.'));
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
            'A batch without lines, or one that does not exist, is answered with the error text and no code. A posting error is answered with Business Central''s text and no code, and the posting is rolled back. ' +
            'The caller needs the BIFROST InvPost ori permission set (without it the call is not listed as enabled) and the table permissions that the standard item journal posting itself needs. The Reclassification domain must be turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.Reclassification.Check first. Inventory.Reclassification.PreviewPost lists the lines but does not simulate the posting, so it cannot predict posting errors.';
        exit(true);
    end;
}
