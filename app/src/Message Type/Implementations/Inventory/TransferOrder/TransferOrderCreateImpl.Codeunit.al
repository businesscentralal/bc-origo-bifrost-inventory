namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Create message type.
/// Creates a new transfer order header (Transfer Header) with from/to locations,
/// posting date, shipment/receipt dates and an optional Direct Transfer flag.
/// Optional lines are created in the same call. Without lines, only the header is created.
/// </summary>

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013414 "Transfer Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.WritePermission());
    end;
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Creates a new transfer order with from/to locations, dates, optional Direct Transfer and optional lines.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'transfer order, move stock, transfer between locations, move goods to another warehouse, stock transfer, relocate inventory', Comment = 'is-IS=millifærslupöntun, flytja birgðir, flutningur milli birgðageymslna, flytja vörur í aðra birgðageymslu, birgðaflutningur';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Creates a new transfer order header and optional lines; use TransferOrder.Release or Post after creation.', Comment = 'is-IS=Býr til nýja millifærslupöntun og valkvæðar línur; notaðu TransferOrder.Release eða Post eftir stofnun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := Parts.GetParameters('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Related := Parts.GetRelated('Inventory.TransferOrder.Create');
        exit(true);
    end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Workflow := Parts.GetWorkflow('Inventory.TransferOrder.Create');
        exit(Workflow.Keys().Count() > 0);
    end;
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Examples := Parts.GetExamples('Inventory.TransferOrder.Create');
        exit(Examples.Count() > 0);
    end;
    procedure GetOverview(var Overview: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.TransferOrder.Create');
        exit(Overview <> '');
    end;
    procedure GetNotes(var Notes: Text): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := Parts.GetNotes('Inventory.TransferOrder.Create');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    begin
        Argument.SetResponseMarkdown('');
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        Dispatcher: Codeunit "Dispatcher ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        Token: JsonToken;
        TransferFromCode: Code[10];
        TransferToCode: Code[10];
        InTransitCode: Code[10];
        ExternalDocNo: Code[35];
        PostingDate: Date;
        ShipmentDate: Date;
        ReceiptDate: Date;
        DirectTransfer: Boolean;
        HasLines: Boolean;
        MissingFromErr: Label 'transferFromCode must be specified in the request JSON.', Locked = true;
        MissingToErr: Label 'transferToCode must be specified in the request JSON.', Locked = true;
        MissingInTransitErr: Label 'inTransitCode must be specified when directTransfer is false.', Locked = true;
        FieldWriteRestrictedErr: Label 'Field %1 is restricted for write. Cannot use value ''%2''.', Comment = '%1 = field caption, %2 = field value', Locked = true;
        ReadOk: Boolean;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();

        // Required: transferFromCode
        if RequestJson.Get('transferFromCode', Token) then
            TransferFromCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TransferFromCode))
        else begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingFromErr, 'transferFromCode', '', '', '');
            exit;
        end;

        // Required: transferToCode
        if RequestJson.Get('transferToCode', Token) then
            TransferToCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(TransferToCode))
        else begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingToErr, 'transferToCode', '', '', '');
            exit;
        end;

        // Enforce field-level write restriction on the principal location fields
        if Dispatcher.IsFieldWriteRestricted(Database::"Transfer Header", TransferHeader.FieldNo("Transfer-from Code")) then begin
            Argument.RespondWithError(StrSubstNo(FieldWriteRestrictedErr, TransferHeader.FieldCaption("Transfer-from Code"), TransferFromCode));
            exit;
        end;
        if Dispatcher.IsFieldWriteRestricted(Database::"Transfer Header", TransferHeader.FieldNo("Transfer-to Code")) then begin
            Argument.RespondWithError(StrSubstNo(FieldWriteRestrictedErr, TransferHeader.FieldCaption("Transfer-to Code"), TransferToCode));
            exit;
        end;

        // Optional: directTransfer
        if not Dispatcher.TryReadBoolean(Argument, RequestJson, 'directTransfer', false, DirectTransfer) then
            exit;

        // Optional: inTransitCode (required when not direct transfer â€” validated by BC during Release,
        // but we surface a friendlier error up front when both flags say it's needed)
        if RequestJson.Get('inTransitCode', Token) then
            InTransitCode := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(InTransitCode));
        if (not DirectTransfer) and (InTransitCode = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingInTransitErr, 'inTransitCode', '', '', '');
            exit;
        end;

        // Optional: posting/shipment/receipt dates
        // Every typed value is read before stopping, so all bad ones are reported together (#136).
        ReadOk := true;
        if not Dispatcher.TryReadDate(Argument, RequestJson, 'postingDate', false, PostingDate) then
            ReadOk := false;
        if not Dispatcher.TryReadDate(Argument, RequestJson, 'shipmentDate', false, ShipmentDate) then
            ReadOk := false;
        if not Dispatcher.TryReadDate(Argument, RequestJson, 'receiptDate', false, ReceiptDate) then
            ReadOk := false;
        if not ReadOk then
            exit;
        if PostingDate = 0D then
            PostingDate := WorkDate();

        // Optional: externalDocumentNo
        if RequestJson.Get('externalDocumentNo', Token) then
            ExternalDocNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ExternalDocNo));

        if not Dispatcher.TryReadLines(RequestJson, Lines, HasLines, Argument) then
            exit;
        if HasLines then
            if not Dispatcher.PrecheckTransferLines(Lines, Argument) then
                exit;

        // Build the Transfer Header. Use Insert(true) to fire OnInsert which assigns the No. from the series.
        TransferHeader.Init();
        TransferHeader."No." := '';
        TransferHeader.Insert(true);

        if DirectTransfer then
            TransferHeader.Validate("Direct Transfer", true);
        TransferHeader.Validate("Transfer-from Code", TransferFromCode);
        TransferHeader.Validate("Transfer-to Code", TransferToCode);
        if not DirectTransfer then
            TransferHeader.Validate("In-Transit Code", InTransitCode);
        TransferHeader.Validate("Posting Date", PostingDate);
        if ShipmentDate <> 0D then
            TransferHeader.Validate("Shipment Date", ShipmentDate);
        if ReceiptDate <> 0D then
            TransferHeader.Validate("Receipt Date", ReceiptDate);
        if ExternalDocNo <> '' then
            TransferHeader.Validate("External Document No.", ExternalDocNo);
        TransferHeader.Modify(true);

        if HasLines then
            InsertTransferLines(TransferHeader, Lines, Argument);

        // Refresh after modification (Validate triggers may have changed other fields)
        TransferHeader.Find();

        BuildSuccessResponse(TransferHeader, ResponseJson);
        if HasLines then
            AddTransferLinesToResponse(TransferHeader, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure InsertTransferLines(TransferHeader: Record "Transfer Header"; Lines: JsonArray; var Argument: Record "Message Argument ori")
    var
        TransferLine: Record "Transfer Line";
        Dispatcher: Codeunit "Dispatcher ori";
        LineToken: JsonToken;
        LineJson: JsonObject;
        LineIndex: Integer;
        NextLineNo: Integer;
    begin
        NextLineNo := 10000;
        for LineIndex := 1 to Lines.Count() do begin
            Lines.Get(LineIndex - 1, LineToken);
            LineJson := LineToken.AsObject();
            TransferLine.Init();
            TransferLine."Document No." := TransferHeader."No.";
            TransferLine."Line No." := NextLineNo;
            TransferLine.Insert(true);
            Dispatcher.ValidateTransferLine(TransferLine, LineJson, LineIndex, Argument);
            TransferLine.Modify(true);
            NextLineNo += 10000;
        end;
    end;

    local procedure AddTransferLinesToResponse(TransferHeader: Record "Transfer Header"; var ResponseJson: JsonObject)
    var
        TransferLine: Record "Transfer Line";
        LinesArray: JsonArray;
        LineJson: JsonObject;
        TotalsJson: JsonObject;
        TotalQuantity: Decimal;
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        if TransferLine.FindSet() then
            repeat
                Clear(LineJson);
                LineJson.Add('lineNo', TransferLine."Line No.");
                LineJson.Add('itemNo', TransferLine."Item No.");
                LineJson.Add('description', TransferLine.Description);
                LineJson.Add('quantity', TransferLine.Quantity);
                LineJson.Add('unitOfMeasureCode', TransferLine."Unit of Measure Code");
                LinesArray.Add(LineJson);
                TotalQuantity += TransferLine.Quantity;
            until TransferLine.Next() = 0;

        TotalsJson.Add('quantity', TotalQuantity);
        ResponseJson.Add('lines', LinesArray);
        ResponseJson.Add('totals', TotalsJson);
    end;

    local procedure BuildSuccessResponse(TransferHeader: Record "Transfer Header"; var ResponseJson: JsonObject)
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', TransferHeader."No.");
        ResponseJson.Add('systemId', Format(TransferHeader.SystemId, 0, 4));
        ResponseJson.Add('transferFromCode', TransferHeader."Transfer-from Code");
        ResponseJson.Add('transferToCode', TransferHeader."Transfer-to Code");
        ResponseJson.Add('inTransitCode', TransferHeader."In-Transit Code");
        ResponseJson.Add('directTransfer', TransferHeader."Direct Transfer");
        ResponseJson.Add('postingDate', Format(TransferHeader."Posting Date", 0, 9));
        ResponseJson.Add('shipmentDate', Format(TransferHeader."Shipment Date", 0, 9));
        ResponseJson.Add('receiptDate', Format(TransferHeader."Receipt Date", 0, 9));
        ResponseJson.Add('externalDocumentNo', TransferHeader."External Document No.");
        ResponseJson.Add('statusAfter', StatusToText(TransferHeader.Status));
    end;

    local procedure StatusToText(StatusValue: Option Open,Released): Text
    begin
        case StatusValue of
            StatusValue::Open:
                exit('Open');
            StatusValue::Released:
                exit('Released');
        end;
        exit('');
    end;
}
