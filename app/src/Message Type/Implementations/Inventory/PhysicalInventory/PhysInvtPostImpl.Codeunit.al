namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 70013465 "Phys. Invt. Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, true));
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success when the batch was posted.', Comment = 'is-IS=Success þegar keyrslan var bókuð.';
        LineCountLbl: Label 'Number of journal lines posted.', Comment = 'is-IS=Fjöldi bókaðra bókunarlína.';
        RegisterLbl: Label 'Item register number created by the post.', Comment = 'is-IS=Númer birgðaskrár sem bókunin bjó til.';
        FromEntryLbl: Label 'First item ledger entry number posted.', Comment = 'is-IS=Fyrsta númer birgðafærslu sem var bókað.';
        ToEntryLbl: Label 'Last item ledger entry number posted.', Comment = 'is-IS=Síðasta númer birgðafærslu sem var bókað.';
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', LineCountLbl));
        Fields.Add(ContractMgt.ResponseField('itemRegisterNo', 'integer', RegisterLbl));
        Fields.Add(ContractMgt.ResponseField('fromEntryNo', 'integer', FromEntryLbl));
        Fields.Add(ContractMgt.ResponseField('toEntryNo', 'integer', ToEntryLbl));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        EmptyWhenLbl: Label 'the physical inventory batch has no lines', Comment = 'is-IS=birgðatalningarbókin hefur engar línur';
        EmptyFixLbl: Label 'Calculate the physical inventory journal, then post the batch.', Comment = 'is-IS=Reiknaðu birgðatalningarbókina og bókaðu síðan keyrsluna.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, EmptyWhenLbl, EmptyFixLbl));
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
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Calculate', 'Calculate physical inventory quantities before posting.'));
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
    var
        NotesLbl: Label 'Posts through Item Jnl.-Post Batch after positioning the first line. An empty batch is PreconditionFailed: received is the batch name, expected is at least one journal line. Calculate Inventory remains Inventory.PhysInventory.Calculate.', Comment = 'is-IS=Bókar í gegnum Item Jnl.-Post Batch eftir að fyrsta línan er sett. Tóm keyrsla er PreconditionFailed: received er heiti keyrslunnar, expected er að minnsta kosti ein bókunarlína. Reikna birgðir er áfram Inventory.PhysInventory.Calculate.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemRegister: Record "Item Register";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
        ItemRegisterNo: Integer;
        FromEntryNo: Integer;
        ToEntryNo: Integer;
        EmptyBatchErr: Label 'The physical inventory batch has no lines.', Comment = 'is-IS=Birgðatalningarbókin hefur engar línur.';
        EmptyBatchExpectedTok: Label 'at least one journal line', Comment = 'is-IS=að minnsta kosti ein bókunarlína';
        EmptyBatchNextStepTok: Label 'Calculate the physical inventory journal, then post the batch.', Comment = 'is-IS=Reiknaðu birgðatalningarbókina og bókaðu síðan keyrsluna.';
        MissingTemplateErr: Label 'journalTemplateName is required.', Comment = 'is-IS=journalTemplateName er skylda.';
        MissingBatchErr: Label 'journalBatchName is required.', Comment = 'is-IS=journalBatchName er skylda.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTemplateErr, 'journalTemplateName', '', '', '');
            exit;
        end;
        TemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(TemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingBatchErr, 'journalBatchName', '', '', '');
            exit;
        end;
        BatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(BatchName));
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        LineCount := ItemJournalLine.Count();
        if not ItemJournalLine.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, EmptyBatchErr, 'journalBatchName', BatchName, EmptyBatchExpectedTok, EmptyBatchNextStepTok);
            exit;
        end;
        if not ItemJnlPostBatch.Run(ItemJournalLine) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        if ItemJournalLine."Line No." <> 0 then
            if ItemRegister.Get(ItemJournalLine."Line No.") then begin
                ItemRegisterNo := ItemRegister."No.";
                FromEntryNo := ItemRegister."From Entry No.";
                ToEntryNo := ItemRegister."To Entry No.";
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('journalTemplateName', TemplateName);
        ResponseJson.Add('journalBatchName', BatchName);
        ResponseJson.Add('lineCount', LineCount);
        ResponseJson.Add('itemRegisterNo', ItemRegisterNo);
        ResponseJson.Add('fromEntryNo', FromEntryNo);
        ResponseJson.Add('toEntryNo', ToEntryNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
