namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

codeunit 70013532 "Reclass Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Previews a reclassification journal batch without posting it.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('preview reclassification, reclass journal preview');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns the reclassification journal lines that Post would process.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reclassification.PreviewPost');
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
        Response.Add('rollback', true);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'journal template or batch is missing');
        Errors.Add(ErrorJson);
        exit(true);
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
        Related.Add('Inventory.Reclassification.Post');
        Related.Add('Inventory.Reclassification.Check');
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
        Overview := 'Reads the reclassification journal batch and returns the lines without posting.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Does not commit. Post remains Inventory.Reclassification.Post.';
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        LineJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        LineCount: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reclassification, Database::"Item Journal Line", false, true) then
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
}
