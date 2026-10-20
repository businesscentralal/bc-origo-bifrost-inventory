namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 10076868 "Item Appl. Reapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reapplies an item ledger entry through Item Jnl.-Post Line.', Comment = 'is-IS=Jafnar vörufærslu aftur með Item Jnl.-Post Line.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reapply item application, apply item ledger entry', Comment = 'is-IS=jafna vöru aftur, jafna vörufærslu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reapplies an outbound item ledger entry to an inbound entry.', Comment = 'is-IS=Jafnar útleiðandi vörufærslu aftur við innleiðandi færslu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemApplication.Reapply');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Item Jnl.-Post Line');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'itemLedgerEntryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'applyToEntryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('itemLedgerEntryNo', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'either item ledger entry was not found');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Item Application Entry');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Unapply the item ledger entry instead of reapplying it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Read the item application before reapplying it.'));
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
        Overview := 'Reapplies an item ledger entry through the standard posting line codeunit.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Calls Item Jnl.-Post Line. It does not insert table 339 directly.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ApplyToItemLedgerEntry: Record "Item Ledger Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemLedgerEntryNo: Integer;
        ApplyToEntryNo: Integer;
        MissingEntryErr: Label 'itemLedgerEntryNo is required.', Comment = 'is-IS=itemLedgerEntryNo er nauðsynlegt.';
        MissingApplyToErr: Label 'applyToEntryNo is required.', Comment = 'is-IS=applyToEntryNo er nauðsynlegt.';
        EntryNotFoundErr: Label 'Item ledger entry %1 was not found.', Comment = '%1 = entry no., is-IS=Vörufærsla %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemLedgerEntryNo', Token) then begin
            Argument.RespondWithError(MissingEntryErr);
            exit;
        end;
        ItemLedgerEntryNo := Token.AsValue().AsInteger();
        if not RequestJson.Get('applyToEntryNo', Token) then begin
            Argument.RespondWithError(MissingApplyToErr);
            exit;
        end;
        ApplyToEntryNo := Token.AsValue().AsInteger();
        if not ItemLedgerEntry.Get(ItemLedgerEntryNo) then begin
            Argument.RespondWithError(StrSubstNo(EntryNotFoundErr, Format(ItemLedgerEntryNo)));
            exit;
        end;
        if not ApplyToItemLedgerEntry.Get(ApplyToEntryNo) then begin
            Argument.RespondWithError(StrSubstNo(EntryNotFoundErr, Format(ApplyToEntryNo)));
            exit;
        end;

        ItemJnlPostLine.ReApply(ItemLedgerEntry, ApplyToEntryNo);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo);
        ResponseJson.Add('applyToEntryNo', ApplyToEntryNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
