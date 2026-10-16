namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Journal;
using Origo.Bifrost;

codeunit 70013496 "Phys. Inv. Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Calculates inventory into a physical inventory journal. Does not post.', Comment = 'is-IS=Reiknar birgðir inn í birgðatalningarbók. Bókar ekki.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'physical inventory, calculate inventory', Comment = 'is-IS=birgðatalning, reikna birgðir';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Fills a physical inventory batch. Posting is Inventory.PhysInventory.Post.', Comment = 'is-IS=Fyllir birgðatalningarbókarkeyrslu. Bókun fer fram með Inventory.PhysInventory.Post.';
    begin
        exit(SelectionDescriptionLbl);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.PhysInventory.Post', 'Post the physical inventory journal after calculation.'));
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
        Overview := 'Runs report Calculate Inventory against a physical inventory journal batch.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        MissingTemplateErr: Label 'journalTemplateName and journalBatchName are required.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) then
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
        ItemJournalLine."Journal Template Name" := JournalTemplateName;
        ItemJournalLine."Journal Batch Name" := JournalBatchName;
        if not TryRunCalculateInventory(ItemJournalLine) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.PhysInventory.Calculate');
        ResponseJson.Add('journalTemplateName', JournalTemplateName);
        ResponseJson.Add('journalBatchName', JournalBatchName);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryRunCalculateInventory(var ItemJournalLine: Record "Item Journal Line")
    var
        CalculateInventory: Report "Calculate Inventory";
    begin
        CalculateInventory.SetItemJnlLine(ItemJournalLine);
        CalculateInventory.UseRequestPage(false);
        CalculateInventory.Run();
    end;
}
