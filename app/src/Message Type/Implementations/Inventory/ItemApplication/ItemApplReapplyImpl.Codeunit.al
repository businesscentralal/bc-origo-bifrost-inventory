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
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the entries are named in data."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.itemLedgerEntryNo', 'entry no.', 'The Entry No. of the item ledger entry that is reapplied.'));
        Target.Add(ContractMgt.TargetEntry('data.applyToEntryNo', 'entry no.', 'The Entry No. of the item ledger entry it is applied to.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', true, 'The Entry No. of the item ledger entry to reapply, sent as a JSON integer.'));
        Parameters.Add(ContractMgt.Parameter('applyToEntryNo', 'integer', true, 'The Entry No. of the item ledger entry to apply it to, sent as a JSON integer.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry that was reapplied.'));
        Fields.Add(ContractMgt.ResponseField('applyToEntryNo', 'integer', 'The item ledger entry it was applied to.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Application domain is turned off in Inventory Setup.', 'Turn on the Item Application domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no write permission on item application entries.', 'Request the permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required entry number is absent.', 'Send the documented entry number parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'An entry number is not a JSON integer.', 'Send entry numbers as JSON integers.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected entry does not exist.', 'Read Inventory.ItemApplication.Get and select an existing entry.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refuses the application change.', 'Correct the application according to the native refusal and retry.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Applies one item ledger entry to another with the standard item application logic: item application entries and the remaining quantities of the two entries change, and item costs can need a new adjustment run. No document is posted. Business Central commits the change when the call finishes.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('Both item ledger entries exist.');
        Preconditions.Add('The posting date of the entry is in an open inventory period.');
        Effect.Add('preconditions', Preconditions);
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
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Use it to remove an existing application entry; this type applies an entry to another one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Use it to read the application entries of an item ledger entry before reapplying it.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Get', 'Read the application entries of the item ledger entry.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Unapply', 'Remove the application entry that should go.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Reapply', 'Apply the item ledger entry to the entry it should be applied to.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Apply item ledger entry 45 to entry 12',
            '{"type":"Inventory.ItemApplication.Reapply","data":{"itemLedgerEntryNo":45,"applyToEntryNo":12}}',
            '{"status":"Success","itemLedgerEntryNo":45,"applyToEntryNo":12}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Applies one item ledger entry to another with the standard item application logic. It posts no document, and Business Central commits the change.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'Both numbers are Entry Nos of item ledger entries; read them with Inventory.ItemApplication.Get first. The standard item application logic decides what is allowed, so its rules apply: for example an entry whose posting date is in a closed inventory period is refused. The refusal text is returned as BusinessCentralError. ' +
            'Missing keys return MissingParameter, non-integer values return InvalidParameterFormat and missing entries return RecordNotFound, each with nextStep. ' +
            'There is no preview. Business Central commits the change when the call finishes, and the change can make item costs need a new run of Inventory.AdjustCost.Run. ' +
            'The caller needs BIFROST Full ori and write permission on item application entries, and the Item Application domain must be on in Inventory Setup.';
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
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemLedgerEntryNo: Integer;
        ApplyToEntryNo: Integer;
        EntryNotFoundErr: Label 'Item ledger entry %1 was not found.', Comment = '%1 = entry no., is-IS=Vörufærsla %1 fannst ekki.';
        ExpectedLbl: Label 'an existing item application or item ledger entry', Comment = 'is-IS=fyrirliggjandi vörujöfnunarfærsla eða vörufærsla';
        NextLbl: Label 'Read Inventory.ItemApplication.Get and send the entry number of an existing record.', Comment = 'is-IS=Lestu Inventory.ItemApplication.Get og sendu færslunúmer fyrirliggjandi færslu.';
        NativeNextLbl: Label 'Correct the item application according to the Business Central refusal and retry.', Comment = 'is-IS=Leiðréttu vörujöfnunina samkvæmt höfnun Business Central og reyndu aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then begin
            Parts.CompleteOlderDomainRefusal(Argument);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not Parts.TryReadEntryNo(RequestJson, 'itemLedgerEntryNo', Argument, ItemLedgerEntryNo) then
            exit;
        if not Parts.TryReadEntryNo(RequestJson, 'applyToEntryNo', Argument, ApplyToEntryNo) then
            exit;
        if not ItemLedgerEntry.Get(ItemLedgerEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, Format(ItemLedgerEntryNo, 0, 9)), 'itemLedgerEntryNo', Format(ItemLedgerEntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;
        if not ApplyToItemLedgerEntry.Get(ApplyToEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(EntryNotFoundErr, Format(ApplyToEntryNo, 0, 9)), 'applyToEntryNo', Format(ApplyToEntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;

        Argument.SetErrorContext('itemLedgerEntryNo', ExpectedLbl, NativeNextLbl);
        ItemJnlPostLine.ReApply(ItemLedgerEntry, ApplyToEntryNo);
        Argument.ClearErrorContext();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo);
        ResponseJson.Add('applyToEntryNo', ApplyToEntryNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
