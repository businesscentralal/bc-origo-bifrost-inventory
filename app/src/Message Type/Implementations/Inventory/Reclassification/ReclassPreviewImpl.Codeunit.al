namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
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
        DescriptionLbl: Label 'Lists the lines of a reclassification journal batch that Post would process, without posting. It does not simulate the ledger entries.', Comment = 'is-IS=Listar línur endurflokkunarbókarkeyrslu sem Post myndi vinna úr, án þess að bóka. Líkir ekki eftir færslum.';
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
        SelectionDescriptionLbl: Label 'Returns the reclassification journal lines that Post would process.', Comment = 'is-IS=Skilar línum endurflokkunarbókar sem Post myndi vinna úr.';
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
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        LineJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        MissingTemplateErr: Label 'journalTemplateName is required.', Comment = 'is-IS=journalTemplateName er nauðsynlegt.';
        MissingBatchErr: Label 'journalBatchName is required.', Comment = 'is-IS=journalBatchName er nauðsynlegt.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError(MissingTemplateErr);
            exit;
        end;
        TemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError(MissingBatchErr);
            exit;
        end;
        BatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(BatchName));

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

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('rollback', true);
        ResponseJson.Add('lineCount', LineCount);
        ResponseJson.Add('lines', Lines);
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
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, 'Item journal template name, at most 10 characters. The template is not looked up.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, 'Name of the journal batch whose lines are listed, at most 10 characters.'));
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the lines were read.'));
        Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true. Nothing is written, so there is nothing to roll back; no posting is simulated.'));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of lines in the batch; 0 when the batch has no lines or does not exist.'));
        Field := ContractMgt.ResponseField('lines', 'array', 'Every line of the batch.');
        Clear(Children);
        Children.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number in the batch.'));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number of the line.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Quantity of the line.'));
        Children.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code of the line.'));
        Children.Add(ContractMgt.ResponseField('newLocationCode', 'string', 'New location code of the line.'));
        Field.Add('children', Children);
        Fields.Add(Field);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Reclassification domain is turned off for this company in Inventory Setup.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the posting permission set BIFROST InvPost ori, which this type requires although it only reads.', 'Ask an administrator for BIFROST InvPost ori.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'journalTemplateName is required.', 'journalTemplateName is absent. The answer carries the error text and no code.', 'Send journalTemplateName.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'journalBatchName is required.', 'journalBatchName is absent. The answer carries the error text and no code.', 'Send journalBatchName.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is written or posted. The lines of the journal batch are read and returned.');
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
            'List the lines of the reclassification batch DEFAULT',
            '{"type":"Inventory.Reclassification.PreviewPost","data":{"journalTemplateName":"RECLASS","journalBatchName":"DEFAULT"}}',
            '{"status":"Success","rollback":true,"lineCount":1,"lines":[{"lineNo":10000,"itemNo":"1000","quantity":5,"locationCode":"BLUE","newLocationCode":"RED"}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Lists the lines of an item journal batch that Inventory.Reclassification.Post would process. It does not simulate the posting.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Despite its name this type only reads the lines of the batch. It runs no posting preview, validates no line and creates no ledger entry, so it cannot show the resulting entries or predict posting errors; rollback is true in every answer only as a marker. ' +
            'The template is not looked up and its type is not checked, and every line of the batch is listed whatever its entry type. An unknown batch is answered Success with lineCount 0. ' +
            'journalTemplateName and journalBatchName are required; a missing one is answered with the error text and no code. The type requires the BIFROST InvPost ori permission set although it only reads, and the Reclassification domain turned on in Inventory Setup (a missing setup row counts as on). ' +
            'Use Inventory.Reclassification.Check to confirm the template type and Inventory.Reclassification.Post to post.';
        exit(true);
    end;
}
