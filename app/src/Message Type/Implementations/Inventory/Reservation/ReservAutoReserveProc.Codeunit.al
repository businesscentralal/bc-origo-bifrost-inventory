namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.Reservation.AutoReserve. The caller has already checked the request shape.
/// </summary>
codeunit 70013432 "Reserv. AutoReserve Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ReservationManagement: Codeunit "Reservation Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        FullAutoReservation: Boolean;
        QuantityToReserve: Decimal;
        QuantityToReserveBase: Decimal;
        ReservedBefore: Decimal;
    begin
        RequestJson := Rec.GetRequestJson();
        if not FindSalesLine(RequestJson, SalesLine) then begin
            Rec.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'The sales line was not found.', 'documentNo', ReadText(RequestJson, 'documentNo'), '', 'Check the document and line no.');
            exit;
        end;
        if not LineCanBeReserved(SalesLine, Item) then begin
            Rec.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The line cannot be reserved.', 'documentNo', SalesLine."Document No.", 'a reservable item line', 'Change the item''s Reserve setting or reserve manually.');
            exit;
        end;
        if RemainingBase(SalesLine) <= 0 then begin
            ResponseJson.Add('status', 'Success');
            ResponseJson.Add('reserved', 0);
            ResponseJson.Add('fullyReserved', true);
            ResponseJson.Add('entries', Entries);
            Rec.SetResponseJson(ResponseJson);
            Rec."Content Type" := Rec.GetContentTypeJson();
            exit;
        end;

        QuantityToReserve := RemainingQuantity(SalesLine);
        QuantityToReserveBase := RemainingBase(SalesLine);
        if RequestJson.Contains('quantity') then begin
            QuantityToReserve := ReadDecimal(RequestJson, 'quantity');
            if QuantityToReserve > RemainingQuantity(SalesLine) then
                QuantityToReserve := RemainingQuantity(SalesLine);
            if SalesLine."Qty. per Unit of Measure" = 0 then
                QuantityToReserveBase := QuantityToReserve
            else
                QuantityToReserveBase := QuantityToReserve * SalesLine."Qty. per Unit of Measure";
        end;

        ReservedBefore := SalesLine."Reserved Quantity";
        ReservationManagement.SetReservSource(SalesLine);
        ReservationManagement.AutoReserve(FullAutoReservation, CopyStr(SalesLine.Description, 1, 100), SalesLine."Shipment Date", QuantityToReserve, QuantityToReserveBase);
        if not FullAutoReservation then
            Error(PartialErr);

        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        CollectEntries(SalesLine, Entries);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('reserved', SalesLine."Reserved Quantity" - ReservedBefore);
        ResponseJson.Add('fullyReserved', true);
        ResponseJson.Add('documentType', Format(SalesLine."Document Type"));
        ResponseJson.Add('documentNo', SalesLine."Document No.");
        ResponseJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson.Add('entries', Entries);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    var
        PartialErr: Label 'Only part of the quantity could be reserved.', Locked = true;

    local procedure FindSalesLine(RequestJson: JsonObject; var SalesLine: Record "Sales Line"): Boolean
    var
        LineId: Guid;
        DocumentType: Enum "Sales Document Type";
        DocumentNo: Code[20];
        LineNo: Integer;
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then
            exit(SalesLine.GetBySystemId(LineId));
        if not ReadSalesDocumentType(ReadText(RequestJson, 'documentType'), DocumentType) then
            exit(false);
        DocumentNo := CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(DocumentNo));
        LineNo := ReadInteger(RequestJson, 'lineNo');
        exit(SalesLine.Get(DocumentType, DocumentNo, LineNo));
    end;

    local procedure LineCanBeReserved(SalesLine: Record "Sales Line"; var Item: Record Item): Boolean
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit(false);
        if SalesLine."No." = '' then
            exit(false);
        if not Item.Get(SalesLine."No.") then
            exit(false);
        if Item.Reserve = Item.Reserve::Never then
            exit(false);
        if (SalesLine."Outstanding Qty. (Base)" <= 0) and (SalesLine."Reserved Qty. (Base)" <= 0) then
            exit(false);
        exit(true);
    end;

    local procedure RemainingQuantity(SalesLine: Record "Sales Line"): Decimal
    begin
        exit(SalesLine."Outstanding Quantity" - SalesLine."Reserved Quantity");
    end;

    local procedure RemainingBase(SalesLine: Record "Sales Line"): Decimal
    begin
        exit(SalesLine."Outstanding Qty. (Base)" - SalesLine."Reserved Qty. (Base)");
    end;

    local procedure CollectEntries(SalesLine: Record "Sales Line"; var Entries: JsonArray)
    var
        ReservationEntry: Record "Reservation Entry";
        EntryJson: JsonObject;
    begin
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if ReservationEntry.FindSet() then
            repeat
                Clear(EntryJson);
                EntryJson.Add('entryNo', ReservationEntry."Entry No.");
                EntryJson.Add('itemNo', ReservationEntry."Item No.");
                EntryJson.Add('quantity', ReservationEntry.Quantity);
                EntryJson.Add('quantityBase', ReservationEntry."Quantity (Base)");
                EntryJson.Add('sourceId', ReservationEntry."Source ID");
                EntryJson.Add('sourceRefNo', ReservationEntry."Source Ref. No.");
                Entries.Add(EntryJson);
            until ReservationEntry.Next() = 0;
    end;

    local procedure ReadSalesDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Sales Document Type"): Boolean
    begin
        case UpperCase(DocumentTypeText) of
            'QUOTE':
                DocumentType := DocumentType::Quote;
            'ORDER':
                DocumentType := DocumentType::Order;
            'INVOICE':
                DocumentType := DocumentType::Invoice;
            'CREDIT MEMO':
                DocumentType := DocumentType::"Credit Memo";
            'BLANKET ORDER':
                DocumentType := DocumentType::"Blanket Order";
            'RETURN ORDER':
                DocumentType := DocumentType::"Return Order";
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
        Result: Decimal;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and Evaluate(Result, Token.AsValue().AsText()) then
            exit(Result);
        exit(0);
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
        Result: Integer;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and Evaluate(Result, Token.AsValue().AsText()) then
            exit(Result);
        exit(0);
    end;

    local procedure ReadGuid(RequestJson: JsonObject; KeyName: Text; var Result: Guid): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;
}
