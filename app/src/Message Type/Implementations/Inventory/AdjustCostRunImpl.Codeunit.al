namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.AdjustCost.Run. Same work as report 795 Adjust Cost - Item Entries, with the job-queue filters.
/// </summary>
codeunit 70013460 "Adjust Cost Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::Costing, Database::Item, false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Runs Adjust Cost - Item Entries with item, category and posting-date filters, and optional post to G/L.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'adjust cost item entries, inventory value correction, post inventory cost to g/l', Comment = 'is-IS=leiðrétta kostnað vörufærslna, leiðrétting birgðaverðmætis, bóka birgðakostnað á fjárhag';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Corrects item value entries for the filtered items. When postToGL is true, the same run posts those corrections to the general ledger. This is report 795, not a journal post.', Comment = 'is-IS=Leiðréttir virðisfærslur síaðra vara. Þegar postToGL er satt bókar sama keyrsla leiðréttingarnar á fjárhag. Þetta er skýrsla 795, ekki bókun dagbókar.';
    begin
        exit(SelectionLbl);
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

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNoFilter: Text;
        ItemCategoryFilter: Text;
        PostingDateFilter: Text;
        ItemByItem: Boolean;
        PostToGL: Boolean;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::Costing, Database::Item, false, true) then
            exit;

        RequestJson := Argument.GetRequestJson();
        ItemNoFilter := ReadText(RequestJson, 'itemNo');
        ItemCategoryFilter := ReadText(RequestJson, 'itemCategoryCode');
        PostingDateFilter := ReadText(RequestJson, 'postingDate');
        ItemByItem := ReadBoolean(RequestJson, 'itemByItem');
        PostToGL := ReadBoolean(RequestJson, 'postToGL');

        Item.Reset();
        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);
        if ItemCategoryFilter <> '' then
            Item.SetFilter("Item Category Code", ItemCategoryFilter);

        Report.Run(Report::"Adjust Cost - Item Entries", false, false, Item);
        if PostToGL then
            Report.Run(Report::"Post Inventory Cost to G/L", false, false, Item);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNoFilter);
        ResponseJson.Add('itemCategoryCode', ItemCategoryFilter);
        ResponseJson.Add('postingDate', PostingDateFilter);
        ResponseJson.Add('itemByItem', ItemByItem);
        ResponseJson.Add('postToGL', PostToGL);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadText(RequestJson: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadBoolean(RequestJson: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(Name, Token) then
            exit(false);
        if Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
