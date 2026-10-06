namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Reapply. Calls Item Jnl.-Post Line.ReApply.
/// </summary>
codeunit 70013492 "Item Appl. Reapply Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Reapplies an outbound item ledger entry to an inbound entry.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('reapply item, item application');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reapplies quantity in base units. Adjust Cost stays a separate type.');
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
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        OutboundEntryNo: Integer;
        InboundEntryNo: Integer;
        MissingOutboundErr: Label 'outboundItemLedgerEntryNo is required.', Locked = true;
        MissingInboundErr: Label 'inboundItemLedgerEntryNo is required.', Locked = true;
        EntryNotFoundErr: Label 'Item ledger entry %1 was not found.', Comment = '%1 = entry no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Ledger Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('outboundItemLedgerEntryNo', Token) then begin
            Argument.RespondWithError(MissingOutboundErr);
            exit;
        end;
        OutboundEntryNo := Token.AsValue().AsInteger();
        if not RequestJson.Get('inboundItemLedgerEntryNo', Token) then begin
            Argument.RespondWithError(MissingInboundErr);
            exit;
        end;
        InboundEntryNo := Token.AsValue().AsInteger();
        if not ItemLedgerEntry.Get(OutboundEntryNo) then begin
            Argument.RespondWithError(StrSubstNo(EntryNotFoundErr, OutboundEntryNo));
            exit;
        end;

        ItemJnlPostLine.ReApply(ItemLedgerEntry, InboundEntryNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.ItemApplication.Reapply');
        ResponseJson.Add('outboundItemLedgerEntryNo', OutboundEntryNo);
        ResponseJson.Add('inboundItemLedgerEntryNo', InboundEntryNo);
        Argument.SetResponseJson(ResponseJson);
    end;
}
