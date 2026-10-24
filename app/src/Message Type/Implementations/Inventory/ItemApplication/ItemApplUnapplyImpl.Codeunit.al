namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

codeunit 10076869 "Item Appl. Unapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Unapplies an item application entry through Item Jnl.-Post Line.', Comment = 'is-IS=Afturkallar vörujöfnun með Item Jnl.-Post Line.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'unapply item application, undo application', Comment = 'is-IS=afturkalla vörujöfnun, afturkalla jöfnun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Unapplies one item application entry by entry number.', Comment = 'is-IS=Afturkallar eina vörujöfnunarfærslu eftir færslunúmeri.';
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
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'entry no.', 'The Entry No. of the item application entry to unapply.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The Entry No. of the item application entry to unapply, sent as a JSON integer. It is the entryNo that Inventory.ItemApplication.Get lists, not an item ledger entry number.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The Entry No. of the item application entry that was removed.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry the removed application entry was recorded under.'));
        Fields.Add(ContractMgt.ResponseField('inboundItemEntryNo', 'integer', 'The inbound item ledger entry of the removed application entry.'));
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
        Effect.Add('changes', 'Removes one item application entry with the standard unapply logic: the application row is deleted and kept in the application history, and the remaining quantities of the two item ledger entries are corrected. Item costs can need a new adjustment run. No document is posted. Business Central commits the change when the call finishes.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('The item application entry exists and its posting date is in an open inventory period.');
        Preconditions.Add('The application is not to an outbound transfer and not a drop shipment.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Get', 'Use it to find the entryNo of the application entry before unapplying it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Use it to apply the item ledger entry to another entry after unapplying it.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Get', 'Read the application entries and take the entryNo of the one to remove.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemApplication.Unapply', 'Remove that application entry.'));
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
            'Unapply item application entry 25',
            '{"type":"Inventory.ItemApplication.Unapply","data":{"entryNo":25}}',
            '{"status":"Success","entryNo":25,"itemLedgerEntryNo":12,"inboundItemEntryNo":3}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Removes one item application entry with the standard unapply logic. It posts no document, and Business Central commits the change.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'entryNo is the Entry No. of an item application entry, as listed by Inventory.ItemApplication.Get. The standard unapply logic decides what can be unapplied: it refuses, for example, an application to an outbound transfer, drop shipments, and entries whose posting date is in a closed inventory period. The refusal text is returned as BusinessCentralError. ' +
            'Missing keys return MissingParameter, non-integer values return InvalidParameterFormat and missing entries return RecordNotFound, each with nextStep. ' +
            'There is no preview. Business Central commits the change when the call finishes, and the change can make item costs need a new run of Inventory.AdjustCost.Run. Use Inventory.ItemApplication.Reapply afterwards to apply the item ledger entry to another entry. ' +
            'The caller needs BIFROST Full ori and write permission on item application entries, and the Item Application domain must be on in Inventory Setup.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemApplicationEntry: Record "Item Application Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        EntryNo: Integer;
        NotFoundErr: Label 'Item application entry %1 was not found.', Comment = '%1 = entry no., is-IS=Vörujöfnunarfærsla %1 fannst ekki.';
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
        if not Parts.TryReadEntryNo(RequestJson, 'entryNo', Argument, EntryNo) then
            exit;
        if not ItemApplicationEntry.Get(EntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, Format(EntryNo, 0, 9)), 'entryNo', Format(EntryNo, 0, 9), ExpectedLbl, NextLbl);
            exit;
        end;

        Argument.SetErrorContext('entryNo', ExpectedLbl, NativeNextLbl);
        ItemJnlPostLine.UnApply(ItemApplicationEntry);
        Argument.ClearErrorContext();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemLedgerEntryNo', ItemApplicationEntry."Item Ledger Entry No.");
        ResponseJson.Add('inboundItemEntryNo', ItemApplicationEntry."Inbound Item Entry No.");
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
