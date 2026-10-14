namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>Reads native applications through an explicitly scoped ledger selection and joins both ledger sides.</summary>
codeunit 70013494 "Inventory Application Read ori"
{
    Access = Internal;

    var
        ScopeErr: Label 'Specify exactly one of itemNo and itemLedgerEntryNo.', Comment = 'is-IS=Tilgreindu nákvæmlega eitt af itemNo og itemLedgerEntryNo.';
        ParameterErr: Label 'Invalid application query parameter %1.', Comment = '%1 = parameter name; is-IS=Ógild færibreyta %1 í fyrirspurn um vörujöfnun.';

    procedure Read(var Argument: Record "Message Argument ori")
    var
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Rows: JsonArray;
        Token: JsonToken;
        ApplicationNos: List of [Integer];
        EntryNo: Integer;
        Parameter: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach Parameter in Request.Keys() do
            if not (Parameter in ['itemNo', 'itemLedgerEntryNo', 'locationCode', 'variantCode']) then
                Error(ParameterErr, Parameter);
        if Request.Contains('itemNo') = Request.Contains('itemLedgerEntryNo') then
            Error(ScopeErr);
        if Request.Contains('itemNo') then
            Ledger.SetRange("Item No.", ReadText(Request, 'itemNo', MaxStrLen(Ledger."Item No."), false))
        else begin
            Request.Get('itemLedgerEntryNo', Token);
            Ledger.Get(ReadEntryNo(Token));
            Ledger.SetRange("Entry No.", Ledger."Entry No.");
        end;
        if Request.Contains('locationCode') then
            Ledger.SetRange("Location Code", ReadText(Request, 'locationCode', MaxStrLen(Ledger."Location Code"), true));
        if Request.Contains('variantCode') then
            Ledger.SetRange("Variant Code", ReadText(Request, 'variantCode', MaxStrLen(Ledger."Variant Code"), true));
        if Ledger.FindSet() then
            repeat
                Application.SetRange("Inbound Item Entry No.", Ledger."Entry No.");
                Collect(Application, ApplicationNos);
                Application.SetRange("Inbound Item Entry No.");
                Application.SetRange("Outbound Item Entry No.", Ledger."Entry No.");
                Collect(Application, ApplicationNos);
                Application.SetRange("Outbound Item Entry No.");
            until Ledger.Next() = 0;
        foreach EntryNo in ApplicationNos do begin
            Application.Get(EntryNo);
            Clear(Row);
            Row.Add('entryNo', Application."Entry No.");
            Row.Add('itemLedgerEntryNo', Application."Item Ledger Entry No.");
            Row.Add('inboundItemEntryNo', Application."Inbound Item Entry No.");
            Row.Add('outboundItemEntryNo', Application."Outbound Item Entry No.");
            Row.Add('quantity', Application.Quantity);
            Row.Add('inboundEntry', LedgerJson(Application."Inbound Item Entry No."));
            Row.Add('outboundEntry', LedgerJson(Application."Outbound Item Entry No."));
            Rows.Add(Row);
        end;
        Response.Add('status', 'Success');
        if Request.Get('itemLedgerEntryNo', Token) then
            Response.Add('itemLedgerEntryNo', Token);
        Response.Add('entries', Rows);
        Response.Add('count', Rows.Count());
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure Collect(var Application: Record "Item Application Entry"; var EntryNos: List of [Integer])
    begin
        if Application.FindSet() then
            repeat
                if not EntryNos.Contains(Application."Entry No.") then
                    EntryNos.Add(Application."Entry No.");
            until Application.Next() = 0;
    end;

    local procedure LedgerJson(EntryNo: Integer) Result: JsonObject
    var
        Ledger: Record "Item Ledger Entry";
    begin
        Result.Add('entryNo', EntryNo);
        Result.Add('exists', Ledger.Get(EntryNo));
        if Ledger."Entry No." <> 0 then begin
            Result.Add('itemNo', Ledger."Item No.");
            Result.Add('locationCode', Ledger."Location Code");
            Result.Add('variantCode', Ledger."Variant Code");
            Result.Add('quantity', Ledger.Quantity);
            Result.Add('remainingQuantity', Ledger."Remaining Quantity");
            Result.Add('positive', Ledger.Positive);
            Result.Add('open', Ledger.Open);
            Result.Add('documentNo', Ledger."Document No.");
        end;
    end;

    local procedure ReadText(Request: JsonObject; Name: Text; MaxLength: Integer; AllowEmpty: Boolean): Text
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Text;
    begin
        Request.Get(Name, Token);
        if not Token.IsValue() then
            Error(ParameterErr, Name);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            Error(ParameterErr, Name);
        Value := Token.AsValue().AsText();
        if (StrLen(Value) > MaxLength) or ((Value = '') and not AllowEmpty) then
            Error(ParameterErr, Name);
        exit(Value);
    end;

    local procedure ReadEntryNo(Token: JsonToken): Integer
    var
        Serialized: Text;
        Value: Decimal;
    begin
        if not Token.IsValue() then
            Error(ParameterErr, 'itemLedgerEntryNo');
        Token.WriteTo(Serialized);
        if not Evaluate(Value, Serialized, 9) then
            Error(ParameterErr, 'itemLedgerEntryNo');
        if (Value <= 0) or (Value > 2147483647) or (Value <> Round(Value, 1)) then
            Error(ParameterErr, 'itemLedgerEntryNo');
        exit(Value);
    end;
}
