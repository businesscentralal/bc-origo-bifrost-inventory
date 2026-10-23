namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Reads Item Application Entry.
/// </summary>
codeunit 10076867 "Item Appl. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

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
    var
        DescriptionLbl: Label 'Reads item application entries for an item ledger entry.', Comment = 'is-IS=Les vörujöfnunarfærslur fyrir vörufærslu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item application, applied entries', Comment = 'is-IS=vörujöfnun, jafnaðar færslur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads application entries. Unapply and reapply are separate types.', Comment = 'is-IS=Les jöfnunarfærslur. Afturköllun og endurjöfnun eru aðskildar tegundir.';
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
        Target.Add(ContractMgt.TargetEntry('data.itemLedgerEntryNo', 'entry no.', 'The Entry No. of the item ledger entry whose application entries are listed.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemLedgerEntryNo', 'integer', true, 'The Entry No. of an item ledger entry, sent as a JSON integer. An entry number that does not exist gives an empty list, not an error.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Entries: JsonObject;
        Children: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry number that was asked for.'));
        Children.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The Entry No. of the item application entry; use it as entryNo in Inventory.ItemApplication.Unapply.'));
        Children.Add(ContractMgt.ResponseField('itemLedgerEntryNo', 'integer', 'The item ledger entry the application entry is recorded under.'));
        Children.Add(ContractMgt.ResponseField('inboundItemEntryNo', 'integer', 'The inbound item ledger entry of the application.'));
        Children.Add(ContractMgt.ResponseField('outboundItemEntryNo', 'integer', 'The outbound item ledger entry of the application; 0 when there is none.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The applied quantity of the application entry.'));
        Entries := ContractMgt.ResponseField('entries', 'array', 'The application entries recorded under the item ledger entry; empty when there are none.');
        Entries.Add('children', Children);
        Fields.Add(Entries);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemLedgerEntryNo is not sent.', 'Send the Entry No. of the item ledger entry in data.itemLedgerEntryNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Application domain is turned off in Inventory Setup.', 'Turn on the Item Application domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read item application entries.', 'Request read permission on item application entries from an administrator.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The conversion error text of Business Central.', 'itemLedgerEntryNo is not an integer, or is not a JSON value. The text is returned as it is, with code BusinessCentralError.', 'Send the entry number as a JSON integer.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Lists the item application entries recorded under one item ledger entry number.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Item Application domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read item application entries.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Unapply', 'Use it to remove one application entry that this type listed; this type changes nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemApplication.Reapply', 'Use it to apply an item ledger entry to another entry; this type changes nothing.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'List the application entries recorded under item ledger entry 12',
            '{"type":"Inventory.ItemApplication.Get","data":{"itemLedgerEntryNo":12}}',
            '{"status":"Success","itemLedgerEntryNo":12,"entries":[{"entryNo":25,"itemLedgerEntryNo":12,"inboundItemEntryNo":3,"outboundItemEntryNo":12,"quantity":-5}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Lists the item application entries recorded under one item ledger entry number. It reads only and changes nothing.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'The list holds the application entries recorded under the given item ledger entry number, that is the rows created when that entry was posted or applied. For an outbound entry they show the inbound entries it was applied to. For an inbound entry they show the rows recorded for that entry itself; outbound entries that were applied to it later are recorded under their own numbers, so read those entries to see them. ' +
            'An entry number that does not exist returns an empty list, not RecordNotFound. Use entryNo from the list with Inventory.ItemApplication.Unapply. ' +
            'The caller needs BIFROST Read ori and read permission on item application entries, and the Item Application domain must be on in Inventory Setup.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ItemApplicationEntry: Record "Item Application Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        Token: JsonToken;
        ItemLedgerEntryNo: Integer;
        MissingEntryErr: Label 'itemLedgerEntryNo is required.', Comment = 'is-IS=itemLedgerEntryNo er nauðsynlegt.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemLedgerEntryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingEntryErr, 'itemLedgerEntryNo', '', '', '');
            exit;
        end;
        ItemLedgerEntryNo := Token.AsValue().AsInteger();
        ItemApplicationEntry.SetRange("Item Ledger Entry No.", ItemLedgerEntryNo);
        if ItemApplicationEntry.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', ItemApplicationEntry."Entry No.");
                EntryJson.Add('itemLedgerEntryNo', ItemApplicationEntry."Item Ledger Entry No.");
                EntryJson.Add('inboundItemEntryNo', ItemApplicationEntry."Inbound Item Entry No.");
                EntryJson.Add('outboundItemEntryNo', ItemApplicationEntry."Outbound Item Entry No.");
                EntryJson.Add('quantity', ItemApplicationEntry.Quantity);
                Entries.Add(EntryJson);
            until ItemApplicationEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemLedgerEntryNo', ItemLedgerEntryNo);
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
