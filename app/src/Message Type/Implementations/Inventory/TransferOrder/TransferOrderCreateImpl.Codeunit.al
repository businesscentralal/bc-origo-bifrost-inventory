namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Location;
using Origo.Bifrost;

/// <summary>
/// Implementation of Inventory.TransferOrder.Create.
/// </summary>
codeunit 10076902 "Transfer Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Header", true, false));
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'Creates a new transfer order with from/to locations, dates, optional Direct Transfer and optional lines.', Comment = 'is-IS=Býr til nýja millifærslupöntun með uppruna- og móttökubirgðageymslum, dagsetningum, valkvæðri beinni millifærslu og valkvæðum línum.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'transfer order, move stock, transfer between locations, move goods to another warehouse, stock transfer, relocate inventory', Comment = 'is-IS=millifærslupöntun, flytja birgðir, flutningur milli birgðageymslna, flytja vörur í aðra birgðageymslu, birgðaflutningur, færa birgðir til';
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
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        Location: Record Location;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestValueReader: Codeunit "Request Value Reader ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Lines: JsonArray;
        TransferFromCode: Code[10];
        TransferToCode: Code[10];
        InTransitCode: Code[10];
        ExternalDocNo: Code[35];
        PostingDate: Date;
        ShipmentDate: Date;
        ReceiptDate: Date;
        DirectTransfer: Boolean;
        HasLines: Boolean;
        MissingInTransitErr: Label 'inTransitCode must be specified when directTransfer is false.', Comment = 'is-IS=inTransitCode verður að vera tilgreint þegar directTransfer er false.';
        FieldWriteRestrictedErr: Label 'Field %1 is restricted for write. Cannot use value ''%2''.', Comment = '%1 = field caption, %2 = field value, is-IS=Ritun í reitinn %1 er takmörkuð. Ekki má nota gildið ''%2''.';
        ReadOk: Boolean;
        MissingLocationErr: Label '%1 %2 was not found.', Comment = '%1 = parameter name, %2 = location code; is-IS=%1 %2 fannst ekki.';
        LocationExpectedTxt: Label 'An existing location code appropriate for this transfer.', Comment = 'is-IS=Staðsetningarkóði sem er til og á við um þennan flutning.';
        LocationNextStepTxt: Label 'Correct the from, to and in-transit locations and every reported request value.', Comment = 'is-IS=Leiðréttu uppruna-, áfangastaðar- og millifærslustaðsetningar og öll tilgreind gildi beiðninnar.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();

        TransferFromCode := CopyStr(Parts.ReadRequestText(Argument, RequestJson, 'transferFromCode', true, 10), 1, 10);
        TransferToCode := CopyStr(Parts.ReadRequestText(Argument, RequestJson, 'transferToCode', true, 10), 1, 10);
        InTransitCode := CopyStr(Parts.ReadRequestText(Argument, RequestJson, 'inTransitCode', false, 10), 1, 10);
        ExternalDocNo := CopyStr(Parts.ReadRequestText(Argument, RequestJson, 'externalDocumentNo', false, 35), 1, 35);
        ReadOk := RequestValueReader.TryReadBoolean(Argument, RequestJson, 'directTransfer', false, DirectTransfer);
        if ReadOk and (not DirectTransfer) and (InTransitCode = '') then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, MissingInTransitErr, 'inTransitCode', '<missing>', LocationExpectedTxt, LocationNextStepTxt);
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'postingDate', false, PostingDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'shipmentDate', false, ShipmentDate) then
            ReadOk := false;
        if not RequestValueReader.TryReadDate(Argument, RequestJson, 'receiptDate', false, ReceiptDate) then
            ReadOk := false;
        if (TransferFromCode <> '') and not Location.Get(TransferFromCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingLocationErr, 'transferFromCode', TransferFromCode), 'transferFromCode', TransferFromCode, LocationExpectedTxt, LocationNextStepTxt);
        if (TransferToCode <> '') and not Location.Get(TransferToCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingLocationErr, 'transferToCode', TransferToCode), 'transferToCode', TransferToCode, LocationExpectedTxt, LocationNextStepTxt);
        if (InTransitCode <> '') and not Location.Get(InTransitCode) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MissingLocationErr, 'inTransitCode', InTransitCode), 'inTransitCode', InTransitCode, LocationExpectedTxt, LocationNextStepTxt);
        if not RequestValueReader.TryReadLines(RequestJson, Lines, HasLines, Argument) then
            ReadOk := false;
        if HasLines then
            if not RequestValueReader.PrecheckTransferLines(Lines, Argument) then
                ReadOk := false;
        if Parts.RespondToProblems(Argument) or not ReadOk then
            exit;
        if RequestValueReader.IsFieldWriteRestricted(Database::"Transfer Header", TransferHeader.FieldNo("Transfer-from Code")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(FieldWriteRestrictedErr, TransferHeader.FieldCaption("Transfer-from Code"), TransferFromCode), 'transferFromCode', TransferFromCode, LocationExpectedTxt, LocationNextStepTxt);
            exit;
        end;
        if RequestValueReader.IsFieldWriteRestricted(Database::"Transfer Header", TransferHeader.FieldNo("Transfer-to Code")) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(FieldWriteRestrictedErr, TransferHeader.FieldCaption("Transfer-to Code"), TransferToCode), 'transferToCode', TransferToCode, LocationExpectedTxt, LocationNextStepTxt);
            exit;
        end;
        if PostingDate = 0D then
            PostingDate := WorkDate();

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
        RequestValueReader: Codeunit "Request Value Reader ori";
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
            RequestValueReader.ValidateTransferLine(TransferLine, LineJson, LineIndex, Argument);
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
