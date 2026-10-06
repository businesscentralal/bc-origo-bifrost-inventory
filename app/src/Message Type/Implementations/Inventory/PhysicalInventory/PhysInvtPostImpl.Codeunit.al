namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Counting.Journal;
using Origo.Bifrost;

codeunit 70013534 "Phys. Invt. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::PhysicalInventory, Database::"Item Journal Line", true, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Posts a physical inventory journal batch through Item Jnl.-Post.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('post physical inventory, post count journal');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Posts the physical inventory journal batch after the count is entered.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.PhysInventory.Post');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item Journal Line');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'journalTemplateName');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'journalBatchName');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('lineCount', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'NothingToPost');
        ErrorJson.Add('when', 'the batch has no lines');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Item Ledger Entry');
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
        Overview := 'Posts the physical inventory journal batch.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Uses Item Jnl.-Post. Calculate Inventory remains a separate message type.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalLine: Record "Item Journal Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJnlPost: Codeunit "Item Jnl.-Post";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysicalInventory, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError('journalTemplateName is required.');
            exit;
        end;
        TemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError('journalBatchName is required.');
            exit;
        end;
        BatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(BatchName));
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        LineCount := ItemJournalLine.Count();
        if LineCount = 0 then begin
            Argument.RespondWithError('The physical inventory batch has no lines.');
            exit;
        end;
        ItemJnlPost.Run(ItemJournalLine);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('journalTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        ResponseJson.Add('lineCount', LineCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
