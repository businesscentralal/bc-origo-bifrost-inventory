namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>
/// Inventory.Reclassification.Check. Validates a reclassification journal line. Does not post.
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
        exit('Checks a reclassification journal line. Does not post.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reclassification journal, change item location, change lot', Comment = 'is-IS=endurflokkunarfærsla, breyta staðsetningu vöru, breyta lotu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Validates a reclassification journal line. Posting is a separate type.', Comment = 'is-IS=Staðfestir endurflokkunarlinu. Bókun er sérstök tegund.';
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
        ItemJournalLine: Record "Item Journal Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        LineNo: Integer;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::Reclassification, Database::"Item Journal Line", true, false) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('journalTemplateName', Token) and Token.IsValue() then
            JournalTemplateName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(JournalTemplateName));
        if RequestJson.Get('journalBatchName', Token) and Token.IsValue() then
            JournalBatchName := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(JournalBatchName));
        if RequestJson.Get('lineNo', Token) and Token.IsValue() then
            LineNo := Token.AsValue().AsInteger();
        if not ItemJournalLine.Get(JournalTemplateName, JournalBatchName, LineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'Reclassification journal line was not found.', 'lineNo', Format(LineNo), '', '');
            exit;
        end;
        if ItemJournalLine."Entry Type" <> ItemJournalLine."Entry Type"::Transfer then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'Line is not a reclassification journal line.', 'entryType', Format(ItemJournalLine."Entry Type"), '', '');
            exit;
        end;

        ItemJournalLine.TestField("Item No.");
        ItemJournalLine.TestField(Quantity);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('lineNo', LineNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
