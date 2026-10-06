namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Returns application rows for an item ledger entry.
/// </summary>
codeunit 70013473 "Item Appl Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled(Enum::"Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Application Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns item application entries for one item ledger entry.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'get item application, applied item ledger entries', Comment = 'is-IS=sækja vörujöfnun, jafnaðar vörufærslur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reads item application entries. Does not unapply or reapply.', Comment = 'is-IS=Les vörujöfnunarfærslur. Afturkallar ekki og endurjafnar ekki.';
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
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemApplicationEntry: Record "Item Application Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        EntryJson: JsonObject;
        Token: JsonToken;
        ItemLedgerEntryNo: Integer;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not DomainGate.AssertEnabled(Argument, Enum::"Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", false, false) then
            exit;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemLedgerEntryNo', Token) and Token.IsValue() then
            ItemLedgerEntryNo := Token.AsValue().AsInteger();
        if ItemLedgerEntryNo = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'itemLedgerEntryNo is required.', 'itemLedgerEntryNo', '', '', '');
            exit;
        end;

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
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
