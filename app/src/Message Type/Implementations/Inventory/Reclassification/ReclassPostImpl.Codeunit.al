namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reclassification.Post. Posts a reclassification journal batch through Item Jnl.-Post Batch.
/// </summary>
codeunit 70013493 "Reclass Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Posts an item reclassification journal. This is not a transfer order.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('reclassification journal, post reclassification');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Posts a reclassification journal. Does not create a transfer order.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
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
        exit(false);
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
        ItemJournalLine: Record "Item Journal Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        MissingTemplateErr: Label 'journalTemplateName is required.', Locked = true;
        MissingBatchErr: Label 'journalBatchName is required.', Locked = true;
        EmptyBatchErr: Label 'Reclassification batch %1 %2 has no lines.', Comment = '%1 = template, %2 = batch', Locked = true;
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
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        if not ItemJournalLine.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::NothingToPost, StrSubstNo(EmptyBatchErr, TemplateName, BatchName), 'journalBatchName', '', '', '');
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
}
