namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemApplication.Reapply. Links an outbound item ledger entry to an inbound entry.
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
        ItemApplicationEntry: Record "Item Application Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        OutboundEntryNo: Integer;
        InboundEntryNo: Integer;
        Quantity: Decimal;
        MissingOutboundErr: Label 'outboundItemEntryNo is required.', Locked = true;
        MissingInboundErr: Label 'inboundItemEntryNo is required.', Locked = true;
        NotFoundErr: Label 'Item ledger entry %1 was not found.', Comment = '%1 = entry no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemApplication, Database::"Item Application Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('outboundItemEntryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingOutboundErr, 'outboundItemEntryNo', '', '', '');
            exit;
        end;
        OutboundEntryNo := Token.AsValue().AsInteger();
        if not RequestJson.Get('inboundItemEntryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingInboundErr, 'inboundItemEntryNo', '', '', '');
            exit;
        end;
        InboundEntryNo := Token.AsValue().AsInteger();
        if not ItemLedgerEntry.Get(OutboundEntryNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, OutboundEntryNo), 'outboundItemEntryNo', '', '', '');
            exit;
        end;
        Quantity := Abs(ItemLedgerEntry.Quantity);
        if RequestJson.Get('quantity', Token) then
            Quantity := Token.AsValue().AsDecimal();
        ItemApplicationEntry.Init();
        ItemApplicationEntry."Item Ledger Entry No." := OutboundEntryNo;
        ItemApplicationEntry."Inbound Item Entry No." := InboundEntryNo;
        ItemApplicationEntry."Outbound Item Entry No." := OutboundEntryNo;
        ItemApplicationEntry.Quantity := Quantity;
        ItemApplicationEntry."Posting Date" := ItemLedgerEntry."Posting Date";
        ItemApplicationEntry.Insert(true);
        if Item.Get(ItemLedgerEntry."Item No.") then
            if Item."Cost is Adjusted" then begin
                Item."Cost is Adjusted" := false;
                Item.Modify(true);
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', ItemApplicationEntry."Entry No.");
        ResponseJson.Add('outboundItemEntryNo', OutboundEntryNo);
        ResponseJson.Add('inboundItemEntryNo', InboundEntryNo);
        ResponseJson.Add('quantity', Quantity);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
