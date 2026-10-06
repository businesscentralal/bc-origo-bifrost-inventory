namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Get. Reads Item Application Entry.
/// </summary>
codeunit 70013490 "Item Appl. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Reads item application entries for an item ledger entry.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('item application, applied entries');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reads application entries. Unapply and reapply are separate types.');
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
        MissingEntryErr: Label 'itemLedgerEntryNo is required.', Locked = true;
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
