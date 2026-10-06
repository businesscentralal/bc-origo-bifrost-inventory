namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

codeunit 70013502 "Phys. Inv. Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Journal Line");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Previews physical inventory differences. Does not post.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('physical inventory preview, count difference');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns physical inventory lines where counted quantity differs from calculated quantity.');
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
        Related.Add('Inventory.PhysInventory.Check');
        Related.Add('Inventory.PhysInventory.Post');
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
        Overview := 'Reads physical inventory differences without posting.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJournalLine: Record "Item Journal Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        LineJson: JsonObject;
        Token: JsonToken;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        MissingTemplateErr: Label 'journalTemplateName and journalBatchName are required.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", false, false) then
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
        if ItemJournalLine.FindSet() then
            repeat
                if ItemJournalLine."Qty. (Phys. Inventory)" = ItemJournalLine."Qty. (Calculated)" then
                    continue;
                Clear(LineJson);
                LineJson.Add('lineNo', ItemJournalLine."Line No.");
                LineJson.Add('itemNo', ItemJournalLine."Item No.");
                LineJson.Add('locationCode', ItemJournalLine."Location Code");
                LineJson.Add('qtyCalculated', ItemJournalLine."Qty. (Calculated)");
                LineJson.Add('qtyPhysical', ItemJournalLine."Qty. (Phys. Inventory)");
                Lines.Add(LineJson);
            until ItemJournalLine.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.PhysInventory.Preview');
        ResponseJson.Add('journalTemplateName', JournalTemplateName);
        ResponseJson.Add('journalBatchName', JournalBatchName);
        ResponseJson.Add('lines', Lines);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
