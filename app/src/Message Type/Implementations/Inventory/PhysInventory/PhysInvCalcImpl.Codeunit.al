namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Item;
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
        KeywordsLbl: Label 'physical inventory, calculate inventory, posting date, item filter', Comment = 'is-IS=birgðatalning, reikna birgðir, bókunardagsetning, vörusía';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Fills a physical inventory batch. Posting is Inventory.PhysInventory.Post.', Comment = 'is-IS=Fyllir birgðatalningarbók. Bókun er Inventory.PhysInventory.Post.';
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
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('report', 'Calculate Inventory');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        JournalTemplateLbl: Label 'Physical inventory journal template.', Comment = 'is-IS=Sniðmát birgðatalningarbókar.';
        JournalBatchLbl: Label 'Physical inventory journal batch.', Comment = 'is-IS=Keyrsla birgðatalningarbókar.';
        PostingDateLbl: Label 'Posting date in YYYY-MM-DD format. Required by Calculate Inventory.', Comment = 'is-IS=Bókunardagsetning á forminu ÁÁÁÁ-MM-DD. Reikna birgðir krefst hennar.';
        ItemNoFilterLbl: Label 'Optional item number filter. Omit only when every item should be calculated.', Comment = 'is-IS=Valfrjáls sía á vörunúmeri. Sleppið aðeins þegar reikna á allar vörur.';
    begin
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, JournalTemplateLbl));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', true, JournalBatchLbl));
        Parameters.Add(ContractMgt.Parameter('postingDate', 'string', true, PostingDateLbl));
        Parameters.Add(ContractMgt.Parameter('itemNoFilter', 'string', false, ItemNoFilterLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success when the journal batch was filled.', Comment = 'is-IS=Success þegar bókarkeyrslan var fyllt.';
        LineCountLbl: Label 'Number of physical inventory journal lines written.', Comment = 'is-IS=Fjöldi lína sem skrifaðar voru í birgðatalningarbókina.';
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', LineCountLbl));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'postingDate, journalTemplateName, or journalBatchName is missing.', Comment = 'is-IS=postingDate, journalTemplateName eða journalBatchName vantar.';
        MissingFixLbl: Label 'Send postingDate as YYYY-MM-DD together with the physical inventory template and batch.', Comment = 'is-IS=Sendu postingDate sem ÁÁÁÁ-MM-DD ásamt sniðmáti og keyrslu birgðatalningar.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        exit(true);
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
    var
        OverviewLbl: Label 'Runs report Calculate Inventory against a physical inventory journal batch and returns the line count.', Comment = 'is-IS=Keyrir skýrsluna Reikna birgðir á birgðatalningarbók og skilar línufjölda.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'postingDate is required. itemNoFilter is optional; without it the report calculates every item. Posting remains Inventory.PhysInventory.Post.', Comment = 'is-IS=postingDate er skylda. itemNoFilter er valfrjálst; án þess reiknar skýrslan allar vörur. Bókun er áfram Inventory.PhysInventory.Post.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemJournalLine: Record "Item Journal Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestValueReader: Codeunit "Request Value Reader ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        ItemNoFilter: Text;
        PostingDate: Date;
        LineCount: Integer;
        MissingTemplateErr: Label 'journalTemplateName is required.', Comment = 'is-IS=journalTemplateName er skylda.';
        MissingBatchErr: Label 'journalBatchName is required.', Comment = 'is-IS=journalBatchName er skylda.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingTemplateErr, 'journalTemplateName', '', '', '');
            exit;
        end;
        JournalTemplateName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(JournalTemplateName));
        if not RequestJson.Get('journalBatchName', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingBatchErr, 'journalBatchName', '', '', '');
            exit;
        end;
        JournalBatchName := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(JournalBatchName));
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'postingDate', true, PostingDate) then
            exit;
        if RequestJson.Get('itemNoFilter', Token) then
            ItemNoFilter := Token.AsValue().AsText();
        ItemJournalLine."Journal Template Name" := JournalTemplateName;
        ItemJournalLine."Journal Batch Name" := JournalBatchName;
        if not TryRunCalculateInventory(ItemJournalLine, PostingDate, ItemNoFilter) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;
        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
        LineCount := ItemJournalLine.Count();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.PhysInventory.Calculate');
        ResponseJson.Add('journalTemplateName', JournalTemplateName);
        ResponseJson.Add('journalBatchName', JournalBatchName);
        ResponseJson.Add('postingDate', Format(PostingDate, 0, 9));
        ResponseJson.Add('lineCount', LineCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryRunCalculateInventory(var ItemJournalLine: Record "Item Journal Line"; PostingDate: Date; ItemNoFilter: Text)
    var
        Item: Record Item;
        CalculateInventory: Report "Calculate Inventory";
    begin
        CalculateInventory.SetItemJnlLine(ItemJournalLine);
        CalculateInventory.InitializeRequest(PostingDate, '', false, false);
        CalculateInventory.SetHideValidationDialog(true);
        if ItemNoFilter <> '' then begin
            Item.SetFilter("No.", ItemNoFilter);
            CalculateInventory.SetTableView(Item);
        end;
        CalculateInventory.UseRequestPage(false);
        CalculateInventory.Run();
    end;
}
