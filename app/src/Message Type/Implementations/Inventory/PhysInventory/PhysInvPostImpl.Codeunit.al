namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 70013497 "Phys. Inv. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Posts a physical inventory journal through Item Jnl.-Post Batch.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('physical inventory, post inventory count');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Posts a physical inventory batch. Calculate stays a separate type.');
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
        Parameter.Add('name', 'journalTemplateName');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Physical inventory journal template.');
        Parameters.Add(Parameter);
        Clear(Parameter);
        Parameter.Add('name', 'journalBatchName');
        Parameter.Add('type', 'string');
        Parameter.Add('required', true);
        Parameter.Add('description', 'Physical inventory journal batch.');
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
        Effect.Add('writes', true);
        Effect.Add('posts', true);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Related.Add('Inventory.PhysInventory.Calculate');
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
        Overview := 'Posts a physical inventory journal batch through Item Jnl.-Post Batch.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        MissingTemplateErr: Label 'journalTemplateName and journalBatchName are required.', Locked = true;
        NothingToPostErr: Label 'Physical inventory journal %1 %2 has no lines.', Comment = '%1 = template, %2 = batch', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError(MissingTemplateErr);
            exit;
        end;
        JournalTemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(JournalTemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError(MissingTemplateErr);
            exit;
        end;
        JournalBatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(JournalBatchName));
        ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
        if not ItemJournalLine.FindFirst() then begin
            Argument.RespondWithError(StrSubstNo(NothingToPostErr, JournalTemplateName, JournalBatchName));
            exit;
        end;
        ItemJnlPostBatch.Run(ItemJournalLine);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.PhysInventory.Post');
        ResponseJson.Add('journalTemplateName', JournalTemplateName);
        ResponseJson.Add('journalBatchName', JournalBatchName);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
