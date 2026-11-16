namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>Validates selected transfer quantities and isolates the native posting transaction.</summary>
codeunit 10077022 "Partial Transfer Mgt ori"
{
    Access = Internal;

    /// <summary>Checks permissions and request values before starting the isolated posting process.</summary>
    procedure Execute(var Argument: Record "Message Argument ori"; Ship: Boolean)
    var
        Header: Record "Transfer Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        Lookup: Codeunit "Document Lookup ori";
        Process: Codeunit "Partial Transfer Process ori";
        Quantities: Dictionary of [Integer, Decimal];
        Request: JsonObject;
        NativeExpectedLbl: Label 'A transfer order that passes native posting validation.', Comment = 'is-IS=Flutningspöntun sem stenst innbyggða bókunarprófun.';
        NativeNextLbl: Label 'Correct the order or setup and retry. The failed posting and quantity changes were rolled back.', Comment = 'is-IS=Leiðréttu pöntunina eða uppsetningu og reyndu aftur. Misheppnuð bókun og magnbreytingar voru afturkallaðar.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        if not Lookup.FindTransferHeader(Argument, Header) then
            exit;
        if not ValidateRequest(Argument, Header, Ship, Quantities) then
            exit;
        // The dispatcher checks confirmation first. Also validate a supplied count for direct interface callers.
        Request := Argument.GetRequestJson();
        if Request.Contains('expectedCount') then
            if not Argument.ConfirmExpectedCount(Request, 1) then
                exit;
        Process.Configure(Header."No.", Ship);
        Commit();
        if not Process.Run(Argument) then
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'documentNo', Header."No.", NativeExpectedLbl, NativeNextLbl);
    end;

    /// <summary>Validates all lines without writes; repeated under locks immediately before posting.</summary>
    procedure ValidateRequest(var Argument: Record "Message Argument ori"; Header: Record "Transfer Header"; Ship: Boolean; var Quantities: Dictionary of [Integer, Decimal]): Boolean
    var
        TransferLine: Record "Transfer Line";
        Request: JsonObject;
        LinesToken: JsonToken;
        LineToken: JsonToken;
        LineObject: JsonObject;
        NumberToken: JsonToken;
        Serialized: Text;
        QuantityName: Text;
        LineNo: Integer;
        Quantity: Decimal;
        Outstanding: Decimal;
        DirectErr: Label 'Separate shipment and receipt are not available for a direct transfer.', Comment = 'is-IS=Aðskilin afhending og móttaka eru ekki í boði fyrir beinan flutning.';
        DirectExpectedLbl: Label 'A transfer order with an in-transit location.', Comment = 'is-IS=Flutningspöntun með flutningsbirgðageymslu.';
        DirectNextLbl: Label 'Use Inventory.TransferOrder.Post for a direct transfer, or select a non-direct order.', Comment = 'is-IS=Notaðu Inventory.TransferOrder.Post fyrir beinan flutning eða veldu pöntun sem er ekki bein.';
    begin
        Clear(Quantities);
        if Header."Direct Transfer" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, DirectErr, 'documentNo', Header."No.", DirectExpectedLbl, DirectNextLbl);
            exit(false);
        end;
        QuantityName := 'qtyToReceive';
        if Ship then
            QuantityName := 'qtyToShip';
        Request := Argument.GetRequestJson();
        if not Request.Get('lines', LinesToken) then
            exit(InvalidLine(Argument, 'lines'));
        if not LinesToken.IsArray() then
            exit(InvalidLine(Argument, 'lines'));
        if (LinesToken.AsArray().Count() = 0) or (LinesToken.AsArray().Count() > 200) then
            exit(InvalidLine(Argument, 'lines'));
        foreach LineToken in LinesToken.AsArray() do begin
            if not LineToken.IsObject() then
                exit(InvalidLine(Argument, 'lines'));
            LineObject := LineToken.AsObject();
            if not LineObject.Get('lineNo', NumberToken) then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            NumberToken.WriteTo(Serialized);
            if not NumberToken.IsValue() or (DelChr(Serialized, '=', '0123456789') <> '') then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            if not Evaluate(LineNo, Serialized, 9) then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            if (LineNo <= 0) or Quantities.ContainsKey(LineNo) then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            if not LineObject.Get(QuantityName, NumberToken) then
                exit(InvalidLine(Argument, 'lines[].' + QuantityName));
            NumberToken.WriteTo(Serialized);
            if not NumberToken.IsValue() or (DelChr(Serialized, '=', '-+0123456789.eE') <> '') then
                exit(InvalidLine(Argument, 'lines[].' + QuantityName));
            if not Evaluate(Quantity, Serialized, 9) then
                exit(InvalidLine(Argument, 'lines[].' + QuantityName));
            if Quantity <= 0 then
                exit(InvalidLine(Argument, 'lines[].' + QuantityName));
            if not TransferLine.Get(Header."No.", LineNo) then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            if (TransferLine."Derived From Line No." <> 0) or (TransferLine."Item No." = '') then
                exit(InvalidLine(Argument, 'lines[].lineNo'));
            if Ship then
                Outstanding := TransferLine.Quantity - TransferLine."Quantity Shipped"
            else
                Outstanding := TransferLine."Quantity Shipped" - TransferLine."Quantity Received";
            if Quantity > Outstanding then
                exit(InvalidLine(Argument, 'lines[].' + QuantityName));
            Quantities.Add(LineNo, Quantity);
        end;
        exit(true);
    end;

    local procedure InvalidLine(var Argument: Record "Message Argument ori"; ParameterName: Text): Boolean
    var
        InvalidErr: Label 'The transfer line selection or quantity is invalid.', Comment = 'is-IS=Val flutningslínu eða magn er ógilt.';
        ExpectedLbl: Label '1 to 200 distinct existing top-level line numbers, each with a positive numeric quantity no greater than the unshipped or shipped-but-unreceived quantity.', Comment = 'is-IS=1 til 200 aðskilin númer fyrirliggjandi aðallína, hvert með jákvæðu tölulegu magni sem er ekki meira en óafhent magn eða afhent en ómóttekið magn.';
        NextLbl: Label 'Read the transfer lines, remove duplicates and send lineNo with qtyToShip or qtyToReceive within the remaining quantity.', Comment = 'is-IS=Lestu flutningslínurnar, fjarlægðu tvítekningar og sendu lineNo með qtyToShip eða qtyToReceive innan eftirstöðva.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, InvalidErr, ParameterName, '', ExpectedLbl, NextLbl);
        exit(false);
    end;
}
