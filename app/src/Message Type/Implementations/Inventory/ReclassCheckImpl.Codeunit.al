namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reclassification.Check. Validates a reclassification journal. Does not post.
/// </summary>
codeunit 70013475 "Reclass Check Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Checks a reclassification journal. Does not post.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reclassification journal, change item location, change lot', Comment = 'is-IS=endurflokkunarfærsla, breyta staðsetningu vöru, breyta lotu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Validates a reclassification journal. Posting is a separate type.', Comment = 'is-IS=Staðfestir endurflokkun. Bókun er sérstök tegund.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
    begin
        Parameter.Add('name', 'templateName');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Item journal template. journalTemplateName is also accepted.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'batchName');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Item journal batch. journalBatchName is also accepted.');
        Parameters.Add(Parameter);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('Inventory.Reclassification.PreviewPost');
        Related.Add('Inventory.Reclassification.Post');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Checks a reclassification journal. Refuses templates that are not Transfer.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This is not a transfer order.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalLine: Record "Item Journal Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        MissingBatchErr: Label 'templateName and batchName are required.', Locked = true;
        TemplateNotFoundErr: Label 'Item journal template %1 was not found.', Comment = '%1 = template name', Locked = true;
        NotTransferErr: Label 'Template %1 is not a reclassification template.', Comment = '%1 = template name', Locked = true;
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
}
