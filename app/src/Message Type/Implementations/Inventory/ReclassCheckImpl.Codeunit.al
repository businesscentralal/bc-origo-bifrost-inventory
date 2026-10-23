namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reclassification.Check. Validates a reclassification journal. Does not post.
/// </summary>
codeunit 10076887 "Reclass Check Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::Reclassification, Database::"Item Journal Line", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Checks that a journal template is a reclassification template and counts the transfer lines of the batch. It does not validate the lines or post.', Comment = 'is-IS=Athugar hvort bókarsniðmát sé endurflokkunarsniðmát og telur millifærslulínur keyrslunnar. Sannreynir ekki línurnar og bókar ekki.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reclassification journal, change item location, change lot', Comment = 'is-IS=endurflokkunarfærsla, breyta staðsetningu vöru, breyta lotu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Confirms the template type and counts transfer lines. Posting is a separate type.', Comment = 'is-IS=Staðfestir gerð sniðmáts og telur millifærslulínur. Bókun er sérstök tegund.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalLine: Record "Item Journal Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        MissingBatchErr: Label 'templateName and batchName are required.', Comment = 'is-IS=templateName og batchName eru nauðsynleg.';
        TemplateNotFoundErr: Label 'Item journal template %1 was not found.', Comment = '%1 = template name, is-IS=Vörubókarsniðmát %1 fannst ekki.';
        NotTransferErr: Label 'Template %1 is not a reclassification template.', Comment = '%1 = template name, is-IS=Sniðmát %1 er ekki endurflokkunarsniðmát.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::Reclassification, Database::"Item Journal Line", true, false) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('templateName', Token) and Token.IsValue() then
            TemplateName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TemplateName))
        else
            if RequestJson.Get('journalTemplateName', Token) and Token.IsValue() then
                TemplateName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TemplateName));
        if RequestJson.Get('batchName', Token) and Token.IsValue() then
            BatchName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(BatchName))
        else
            if RequestJson.Get('journalBatchName', Token) and Token.IsValue() then
                BatchName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(BatchName));
        if (TemplateName = '') or (BatchName = '') then begin
            Argument.RespondWithError(MissingBatchErr);
            exit;
        end;
        if not ItemJournalTemplate.Get(TemplateName) then begin
            Argument.RespondWithError(StrSubstNo(TemplateNotFoundErr, TemplateName));
            exit;
        end;
        if ItemJournalTemplate.Type <> ItemJournalTemplate.Type::Transfer then begin
            Argument.RespondWithError(StrSubstNo(NotTransferErr, TemplateName));
            exit;
        end;

        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        ItemJournalLine.SetRange("Entry Type", ItemJournalLine."Entry Type"::Transfer);
        LineCount := ItemJournalLine.Count();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.Reclassification.Check');
        ResponseJson.Add('templateName', TemplateName);
        ResponseJson.Add('batchName', BatchName);
        ResponseJson.Add('postedLineCount', LineCount);
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
        Target.Add(ContractMgt.TargetEntry('data.templateName, data.batchName', 'journal template and batch name', 'The item journal template and batch that hold the reclassification lines. data.journalTemplateName and data.journalBatchName are accepted as aliases.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('templateName', 'string', false, 'Item journal template of type Transfer (the reclassification journal), at most 10 characters; read as an upper-case code. Required unless journalTemplateName is sent; templateName wins when both are sent.'));
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', false, 'Alias of templateName, read only when templateName is absent.'));
        Parameters.Add(ContractMgt.Parameter('batchName', 'string', false, 'Name of the journal batch, at most 10 characters; read as an upper-case code. Required unless journalBatchName is sent; batchName wins when both are sent.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'Alias of batchName, read only when batchName is absent.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the template is a reclassification template.'));
        Fields.Add(ContractMgt.ResponseField('messageType', 'string', 'Always Inventory.Reclassification.Check.'));
        Fields.Add(ContractMgt.ResponseField('templateName', 'string', 'The template that was checked.'));
        Fields.Add(ContractMgt.ResponseField('batchName', 'string', 'The batch that was checked.'));
        Fields.Add(ContractMgt.ResponseField('postedLineCount', 'integer', 'Number of lines of the batch whose entry type is Transfer. Despite the name nothing is posted; 0 when the batch has no such lines or does not exist.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Reclassification domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on the Item Journal Line table, which this type requires although it only reads.', 'Ask an administrator for a permission set that grants it, for example BIFROST Full ori.'));
        Errors.Add(ContractMgt.TextErrorEntry('templateName and batchName are required.', 'The template or the batch name is absent or empty. The answer carries the error text and no code.', 'Send templateName and batchName, or their journal aliases.'));
        Errors.Add(ContractMgt.TextErrorEntry('Item journal template %1 was not found.', 'No item journal template has that name. The answer carries the error text and no code.', 'Check templateName.'));
        Errors.Add(ContractMgt.TextErrorEntry('Template %1 is not a reclassification template.', 'The template exists but its type is not Transfer. The answer carries the error text and no code.', 'Use a reclassification template.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is written or posted. The template is looked up and the lines of the batch whose entry type is Transfer are counted.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reclassification.PreviewPost', 'Use it to list the lines of the batch that the posting would process.'));
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
            'Check the reclassification batch DEFAULT',
            '{"type":"Inventory.Reclassification.Check","data":{"templateName":"RECLASS","batchName":"DEFAULT"}}',
            '{"status":"Success","messageType":"Inventory.Reclassification.Check","templateName":"RECLASS","batchName":"DEFAULT","postedLineCount":2}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Confirms that the named item journal template is a reclassification template and counts the transfer lines of the batch. It does not validate the lines and posts nothing.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only: nothing is written or posted. The answer confirms that the template exists and is of type Transfer, and returns the number of lines of the batch with entry type Transfer as postedLineCount; the name is misleading, nothing is posted. ' +
            'The check does not look up the batch, validate the lines or predict posting errors, so an unknown batch is answered Success with postedLineCount 0. templateName and batchName win over the aliases journalTemplateName and journalBatchName when both are sent. ' +
            'A missing name, an unknown template and a template of another type are answered with the error text and no code. ' +
            'The type requires write permission on the Item Journal Line table although it only reads, and the Reclassification domain turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.Reclassification.PreviewPost to list the lines and Inventory.Reclassification.Post to post.';
        exit(true);
    end;
}
