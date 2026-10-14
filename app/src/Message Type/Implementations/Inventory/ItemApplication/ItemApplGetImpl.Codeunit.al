namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Reads Item Application Entry.
/// </summary>
codeunit 70013490 "Item Appl. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads native item applications and both joined ledger entries for one item or entry.', Comment = 'is-IS=Les innbyggðar vörujafnanir og báðar tengdar birgðafærslur fyrir eina vöru eða færslu.';
        KeywordsLbl: Label 'item application, applied entries', Comment = 'is-IS=jöfnun vöru, jafnaðar færslur';
        SelectionDescriptionLbl: Label 'Selects exactly one itemNo or itemLedgerEntryNo, with optional exact location and variant filters.', Comment = 'is-IS=Velur nákvæmlega eitt itemNo eða itemLedgerEntryNo með valkvæðum nákvæmum síum fyrir birgðageymslu og afbrigði.';
        OverviewLbl: Label 'Reads deduplicated applications connected to either side of the selected ledger entries.', Comment = 'is-IS=Les vörujafnanir sem tengjast hvorri hlið valinna birgðafærslna án tvítekningar.';
        NotesLbl: Label 'Read only. Zero or unavailable ledger sides are explicitly identified; unapply and reapply are separate types.', Comment = 'is-IS=Aðeins lestur. Hliðar með núlli eða án aðgengilegrar birgðafærslu eru sérstaklega auðkenndar; afturköllun og endurjöfnun eru aðskildar gerðir.';

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.Add('messageType', 'Inventory.ItemApplication.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        Clear(Target);
        TargetJson.Add('table', 'Item Application Entry');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Exactly one of itemNo and itemLedgerEntryNo is required.'));
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', false, 'Positive entry number; mutually exclusive with itemNo.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Exact location filter; empty selects the blank location.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant filter; empty selects the blank variant.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Response.Add('status', 'Success');
        Response.Add('itemLedgerEntryNo', 0);
        Response.Add('entries', 'array');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the read.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'Included only for an entry selector.'));
        Fields.Add(ContractMgt.ResponseField('entries', 'array', 'Deduplicated applications with entryNo, itemLedgerEntryNo, inboundItemEntryNo, outboundItemEntryNo, quantity and joined inboundEntry/outboundEntry objects. Each joined side reports entryNo and exists; existing sides also report itemNo, locationCode, variantCode, quantity, remainingQuantity, positive, open and documentNo.'));
        Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of returned applications.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Specify exactly one of itemNo and itemLedgerEntryNo.', 'Both selectors or neither selector is supplied.', 'Supply exactly one selector.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native application query error.', 'Malformed or unsupported parameters, or an unknown ledger entry.', 'Correct the selector and exact filters before retrying.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Required Inventory, table or posting permission is missing.', 'Request the required permission from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The company Inventory domain is disabled.', 'Enable the domain from Inventory Setup.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Clear(Effect);
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        Clear(Metering);
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Unapply an item application entry instead of reading it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Reapply an item ledger entry instead of reading applications.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Clear(Workflow);
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        NativeRead: Codeunit "Inventory Application Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        NativeRead.Read(Argument);
    end;
}
