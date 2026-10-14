namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>Native shipment and assembly undo with explicit selection and transaction isolation.</summary>
codeunit 70013487 "Inventory Native Undo ori"
{
    Access = Internal;

    var
        ParameterErr: Label 'Unsupported undo parameter %1.', Comment = '%1 = parameter name; is-IS=Færibreytan %1 fyrir afturköllun er ekki studd.';
        DocumentErr: Label 'documentNo must be nonempty text of at most 20 characters.', Comment = 'is-IS=documentNo verður að vera texti sem er ekki tómur og er að hámarki 20 stafir.';
        LinesErr: Label 'lineNos must be a nonempty array of distinct positive line numbers on this shipment.', Comment = 'is-IS=lineNos verður að vera fylki sem er ekki tómt með aðgreindum jákvæðum línunúmerum í þessari afhendingu.';
        ReceivedErr: Label 'The shipment cannot be undone: its transfer line no longer exists or has already been received.', Comment = 'is-IS=Ekki er hægt að afturkalla afhendinguna: flutningslínan er ekki lengur til eða þegar hefur verið tekið við henni.';
        EmptyErr: Label 'The shipment has no remaining lines to undo.', Comment = 'is-IS=Afhendingin hefur engar línur eftir til að afturkalla.';

    /// <summary>Undoes only selected shipment lines using native Undo Transfer Shipment; no posted rows are deleted directly.</summary>
    [CommitBehavior(CommitBehavior::Ignore)]
    procedure UndoShipment(var Argument: Record "Message Argument ori")
    var
        Header: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        Selected: Record "Transfer Shipment Line";
        NativeShipmentUndo: Codeunit "Undo Transfer Shipment";
        Request: JsonObject;
        Response: JsonObject;
        Result: JsonObject;
        Results: JsonArray;
        Token: JsonToken;
        Entry: JsonToken;
        LineNos: List of [Integer];
        Number: Integer;
        FilterText: Text;
        ParameterName: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['documentNo', 'lineNos']) then
                Error(ParameterErr, ParameterName);
        Header.Get(ReadDocumentNo(Request));
        Line.SetRange("Document No.", Header."No.");
        if Request.Get('lineNos', Token) then begin
            if not Token.IsArray() then
                Error(LinesErr);
            if Token.AsArray().Count() = 0 then
                Error(LinesErr);
            foreach Entry in Token.AsArray() do begin
                Number := ReadLineNo(Entry);
                if LineNos.Contains(Number) then
                    Error(LinesErr);
                LineNos.Add(Number);
                Selected.Get(Header."No.", Number);
                Selected.TestField("Correction Line", false);
                Selected.TestField(Quantity);
                if FilterText <> '' then
                    FilterText += '|';
                FilterText += Format(Number, 0, 9);
            end;
            Line.SetFilter("Line No.", FilterText);
        end else begin
            Line.SetRange("Correction Line", false);
            Line.SetFilter(Quantity, '<>0');
        end;
        if not Line.FindSet() then
            Error(EmptyErr);
        repeat
            CheckTransferLine(Line);
            Clear(Result);
            Result.Add('lineNo', Line."Line No.");
            Result.Add('itemNo', Line."Item No.");
            Result.Add('quantity', Line.Quantity);
            Results.Add(Result);
        until Line.Next() = 0;
        Line.FindFirst();
        NativeShipmentUndo.SetHideDialog(true);
        NativeShipmentUndo.Run(Line);
        Response.Add('status', 'Success');
        Response.Add('documentNo', Header."No.");
        Response.Add('undoneLineCount', Results.Count());
        Response.Add('result', Results);
        SetResponse(Argument, Response);
    end;

    /// <summary>Calls native Assembly-Post.Undo and honors recreateOrder while suppressing internal commits.</summary>
    [CommitBehavior(CommitBehavior::Ignore)]
    procedure UndoAssembly(var Argument: Record "Message Argument ori")
    var
        Header: Record "Posted Assembly Header";
        AssemblyHeader: Record "Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        Reader: Codeunit "Request Value Reader ori";
        Request: JsonObject;
        Response: JsonObject;
        ParameterName: Text;
        RecreateOrder: Boolean;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['documentNo', 'recreateOrder']) then
                Error(ParameterErr, ParameterName);
        if not Reader.TryReadBoolean(Argument, Request, 'recreateOrder', Request.Contains('recreateOrder'), RecreateOrder) then
            exit;
        Header.Get(ReadDocumentNo(Request));
        Header.TestField(Reversed, false);
        AssemblyPost.SetSuppressCommit(true);
        AssemblyPost.Undo(Header, RecreateOrder);
        Header.Get(Header."No.");
        Header.TestField(Reversed, true);
        Response.Add('status', 'Success');
        Response.Add('documentNo', Header."No.");
        Response.Add('reversed', Header.Reversed);
        Response.Add('recreateOrder', RecreateOrder);
        Response.Add('orderNo', Header."Order No.");
        Response.Add('orderExists', AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, Header."Order No."));
        SetResponse(Argument, Response);
    end;

    local procedure CheckTransferLine(ShipmentLine: Record "Transfer Shipment Line")
    var
        TransferLine: Record "Transfer Line";
    begin
        if not TransferLine.Get(ShipmentLine."Transfer Order No.", ShipmentLine."Trans. Order Line No.") then
            Error(ReceivedErr);
        if TransferLine."Qty. Received (Base)" > 0 then
            Error(ReceivedErr);
    end;

    local procedure ReadDocumentNo(Request: JsonObject): Code[20]
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Text;
    begin
        if not Request.Get('documentNo', Token) or not Token.IsValue() then
            Error(DocumentErr);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            Error(DocumentErr);
        Value := Token.AsValue().AsText();
        if (Value = '') or (StrLen(Value) > 20) then
            Error(DocumentErr);
        exit(CopyStr(Value, 1, 20));
    end;

    local procedure ReadLineNo(Token: JsonToken): Integer
    var
        Serialized: Text;
        Number: Decimal;
    begin
        if not Token.IsValue() then
            Error(LinesErr);
        Token.WriteTo(Serialized);
        if not Evaluate(Number, Serialized, 9) then
            Error(LinesErr);
        if (Number <= 0) or (Number > 2147483647) or (Number <> Round(Number, 1)) then
            Error(LinesErr);
        exit(Number);
    end;

    local procedure SetResponse(var Argument: Record "Message Argument ori"; Response: JsonObject)
    begin
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
