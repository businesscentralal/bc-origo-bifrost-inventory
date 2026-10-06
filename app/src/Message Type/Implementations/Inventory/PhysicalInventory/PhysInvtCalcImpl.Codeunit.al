namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Origo.Bifrost;

codeunit 70013535 "Phys. Invt. Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Calculates inventory into a physical inventory journal batch.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('calculate inventory, physical inventory calculate');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Creates physical inventory journal lines for the item filter.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.PhysInventory.Calculate');
        Envelope.Add('version', 1);
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
        Clear(ParameterJson);
        ParameterJson.Add('name', 'itemNoFilter');
        ParameterJson.Add('type', 'text');
        ParameterJson.Add('required', false);
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
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'journal template or batch is missing');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Item Journal Line');
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
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
        Overview := 'Calculates on-hand quantity into the physical inventory journal.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Mirrors report Calculate Inventory by writing Qty. (Calculated) from item inventory.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        TemplateName: Code[10];
        BatchName: Code[10];
        ItemNoFilter: Text;
        LineNo: Integer;
        LineCount: Integer;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::PhysInventory, Database::"Item Journal Line", true, false) then
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
        if RequestJson.Get('itemNoFilter', Token) then
            ItemNoFilter := Token.AsValue().AsText();
        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        if Item.FindSet() then
            repeat
                LineNo += 10000;
                ItemJournalLine.Init();
                ItemJournalLine."Journal Template Name" := TemplateName;
                ItemJournalLine."Journal Batch Name" := BatchName;
                ItemJournalLine."Line No." := LineNo;
                ItemJournalLine.Validate("Item No.", Item."No.");
                ItemJournalLine.Validate("Qty. (Calculated)", Item.Inventory);
                ItemJournalLine.Insert(true);
                LineCount += 1;
            until Item.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('lineCount', LineCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
