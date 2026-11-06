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
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, false));
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
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        NextLbl: Label 'Send templateName and batchName for an existing Transfer journal template.', Comment = 'is-IS=Sendu templateName og batchName fyrir fyrirliggjandi millifærslubókarsniðmát.';

        TemplateNotFoundErr: Label 'Item journal template %1 was not found.', Comment = '%1 = template name, is-IS=Vörubókarsniðmát %1 fannst ekki.';
        NotTransferErr: Label 'Template %1 is not a reclassification template.', Comment = '%1 = template name, is-IS=Sniðmát %1 er ekki endurflokkunarsniðmát.';
    begin
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Contains('templateName') then
            TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'templateName', Argument, true, 10), 1, 10)
        else
            if RequestJson.Contains('journalTemplateName') then
                TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalTemplateName', Argument, true, 10), 1, 10)
            else
                TemplateName := CopyStr(Parts.ReadRequestText(RequestJson, 'templateName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;
        if RequestJson.Contains('batchName') then
            BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'batchName', Argument, true, 10), 1, 10)
        else
            if RequestJson.Contains('journalBatchName') then
                BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'journalBatchName', Argument, true, 10), 1, 10)
            else
                BatchName := CopyStr(Parts.ReadRequestText(RequestJson, 'batchName', Argument, true, 10), 1, 10);
        if Parts.RespondToProblems(Argument) then
            exit;

        if not ItemJournalTemplate.Get(TemplateName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(TemplateNotFoundErr, TemplateName), 'templateName', TemplateName, '', NextLbl);
            exit;
        end;
        if ItemJournalTemplate.Type <> ItemJournalTemplate.Type::Transfer then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotTransferErr, TemplateName), 'templateName', TemplateName, 'Transfer', NextLbl);
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
        ErrorHelp1Lbl: Label 'The Reclassification domain is turned off for this company in Inventory Setup.', Comment = 'is-IS=Slökkt er á endurflokkun fyrir þetta fyrirtæki í birgðauppsetningu.';
        ErrorHelp2Lbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á aðgerðasviðinu á birgðauppsetningarsíðunni.';
        ErrorHelp3Lbl: Label 'The caller has no read permission on the Item Journal Line table.', Comment = 'is-IS=Kallandi hefur ekki lesheimild á vörubókarlínum.';
        ErrorHelp4Lbl: Label 'Ask an administrator for a permission set that grants it, for example BIFROST Read ori.', Comment = 'is-IS=Biddu stjórnanda um heimildasafn sem veitir aðgang, til dæmis BIFROST Read ori.';
        ErrorHelp5Lbl: Label 'templateName and batchName are required.', Comment = 'is-IS=templateName og batchName eru nauðsynleg.';
        ErrorHelp6Lbl: Label 'The template or the batch name is absent or empty.', Comment = 'is-IS=Heiti sniðmáts eða keyrslu vantar eða er tómt.';
        ErrorHelp7Lbl: Label 'Send templateName and batchName, or their journal aliases.', Comment = 'is-IS=Sendu templateName og batchName eða samheitin journalTemplateName og journalBatchName.';
        ErrorHelp8Lbl: Label 'Item journal template %1 was not found.', Comment = '%1 = journal template, is-IS=Vörubókarsniðmát %1 fannst ekki.';
        ErrorHelp9Lbl: Label 'No item journal template has that name.', Comment = 'is-IS=Ekkert vörubókarsniðmát hefur þetta heiti.';
        ErrorHelp10Lbl: Label 'Check templateName.', Comment = 'is-IS=Athugaðu templateName.';
        ErrorHelp11Lbl: Label 'Template %1 is not a reclassification template.', Comment = '%1 = journal template, is-IS=Sniðmát %1 er ekki endurflokkunarsniðmát.';
        ErrorHelp12Lbl: Label 'The template exists but its type is not Transfer.', Comment = 'is-IS=Sniðmátið er til en er ekki af gerðinni Transfer.';
        ErrorHelp13Lbl: Label 'Use a reclassification template.', Comment = 'is-IS=Notaðu endurflokkunarsniðmát.';
        ErrorHelp14Lbl: Label 'A journal selector is not JSON text.', Comment = 'is-IS=Bókarval er ekki JSON-texti.';
        ErrorHelp15Lbl: Label 'Send the documented selector as a JSON string.', Comment = 'is-IS=Sendu skjalfesta valbreytu sem JSON-streng.';
        ErrorHelp16Lbl: Label 'A journal selector exceeds 10 characters.', Comment = 'is-IS=Bókarval er lengra en 10 stafir.';
        ErrorHelp17Lbl: Label 'Use a journal template or batch name of at most 10 characters.', Comment = 'is-IS=Notaðu heiti bókarsniðmáts eða keyrslu með að hámarki 10 stöfum.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp1Lbl, ErrorHelp2Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ErrorHelp3Lbl, ErrorHelp4Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ErrorHelp5Lbl, ErrorHelp6Lbl, ErrorHelp7Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorHelp8Lbl, ErrorHelp9Lbl, ErrorHelp10Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorHelp11Lbl, ErrorHelp12Lbl, ErrorHelp13Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ErrorHelp14Lbl, ErrorHelp15Lbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorHelp16Lbl, ErrorHelp17Lbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is written or posted. The template is looked up and the lines of the batch whose entry type is Transfer are counted.');
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
            'A missing name returns MissingParameter, an unknown template RecordNotFound and a non-Transfer template PreconditionFailed; each refusal includes nextStep. ' +
            'The type requires read permission on the Item Journal Line table, and the Reclassification domain turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.Reclassification.PreviewPost to simulate posting and inspect captured ledger entries and Inventory.Reclassification.Post to post.';
        exit(true);
    end;
}
