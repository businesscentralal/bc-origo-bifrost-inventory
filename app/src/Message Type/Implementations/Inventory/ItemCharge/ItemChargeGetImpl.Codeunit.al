namespace Origo.Bifrost.Inventory;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCharge.Get. Returns the assignment rows for one charge line and the quantity still unassigned.
/// </summary>
codeunit 10036920 "Item Charge Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCharge) then
            exit(false);
        exit(PurchAssignment.ReadPermission() and SalesAssignment.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Charge Assignment (Purch)");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads item charge assignment rows for one charge line.', Comment = 'is-IS=Les úthlutunarlínur vörugjalds fyrir eina gjaldlínu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item charge, assignment, unassigned', Comment = 'is-IS=vörugjald, úthlutun, óúthlutað';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Show how a charge is spread and what is still unassigned.', Comment = 'is-IS=Sýndu hvernig gjaldi er dreift og hvað er enn óúthlutað.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemCharge.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item Charge Assignment');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', true, 'purchase or sales.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Document number. Send this or systemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Document system id. Send this or documentNo.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, 'Charge line number.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        EmptyRows: JsonArray;
    begin
        Response.Add('status', 'Success');
        Response.Add('documentType', '');
        Response.Add('documentNo', '');
        Response.Add('lineNo', 0);
        Response.Add('unassignedQuantity', 0);
        Response.Add('assignments', EmptyRows);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is missing.', 'Send documentType, lineNo, and documentNo or systemId.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong JSON type.', 'Send documentType as text and lineNo as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No document or line matched.', 'Check the document and the line no.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'documentNo and systemId were both sent.', 'Send documentNo or systemId, not both.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The line is not a charge line.', 'Pass the line no. of a Charge (Item) line.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read item charge assignments.', 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        RelatedJson: JsonObject;
    begin
        RelatedJson.Add('name', 'Inventory.ItemCharge.Assign');
        RelatedJson.Add('useInsteadWhen', 'Change the assignment instead of only reading it.');
        Related.Add(RelatedJson);
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('documentType', 'purchase');
        Data.Add('documentNo', 'PO-1001');
        Data.Add('lineNo', 30000);
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads the current item charge assignment rows and the quantity that is still unassigned.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This call does not change the assignment and does not post the document.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        DocumentType: Text;
        DocumentNo: Code[20];
        LineNo: Integer;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson, DocumentType, DocumentNo, LineNo) then
            exit;
        WriteResponse(Argument, DocumentType, DocumentNo, LineNo);
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        DomainDisabledErr: Label 'The Item Charge domain is turned off for this company.', Comment = 'is-IS=Vörugjaldssviðið er slökkt fyrir þetta fyrirtæki.';
    begin
        if (not InventorySetup.ReadPermission()) or (not PurchAssignment.ReadPermission()) or (not SalesAssignment.ReadPermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', 'BIFROST InvRead ori', 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.');
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCharge) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', 'Turn the domain on from the Inventory Setup page.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    begin
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('lineNo') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['documentType', 'documentNo', 'systemId', 'lineNo']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId and lineNo.');
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var DocumentType: Text; var DocumentNo: Code[20]; var LineNo: Integer): Boolean
    begin
        if not RequireText(Argument, RequestJson, 'documentType') then
            exit(false);
        if not RequireInteger(Argument, RequestJson, 'lineNo') then
            exit(false);
        if RequestJson.Contains('documentNo') and RequestJson.Contains('systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send documentNo or systemId, not both.', 'documentNo', '', 'systemId', 'Send documentNo or systemId, not both.');
            exit(false);
        end;
        if (not RequestJson.Contains('documentNo')) and (not RequestJson.Contains('systemId')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentNo or systemId is required.', 'documentNo', '', 'documentNo', 'Send documentNo or systemId.');
            exit(false);
        end;
        if RequestJson.Contains('documentNo') then begin
            if not RequireText(Argument, RequestJson, 'documentNo') then
                exit(false);
        end else
            if not RequireText(Argument, RequestJson, 'systemId') then
                exit(false);
        DocumentType := LowerCase(ReadText(RequestJson, 'documentType'));
        if not (DocumentType in ['purchase', 'sales']) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'documentType must be purchase or sales.', 'documentType', CopyStr(DocumentType, 1, 250), 'purchase|sales', 'Send purchase or sales.');
            exit(false);
        end;
        DocumentNo := CopyStr(ReadDocumentNo(RequestJson, DocumentType), 1, 20);
        LineNo := ReadInteger(RequestJson, 'lineNo');
        if DocumentNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No document matched the request.', 'documentNo', '', '', 'Check the document no.');
            exit(false);
        end;
        if DocumentType = 'purchase' then
            exit(PurchaseLineOk(Argument, DocumentNo, LineNo));
        exit(SalesLineOk(Argument, DocumentNo, LineNo));
    end;

    local procedure PurchaseLineOk(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; LineNo: Integer): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
    begin
        PurchHeader.SetRange("No.", DocumentNo);
        if not PurchHeader.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No document matched the request.', 'documentNo', DocumentNo, '', 'Check the document no.');
            exit(false);
        end;
        if not PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", LineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No line matched the request.', 'lineNo', Format(LineNo), '', 'Check the line no.');
            exit(false);
        end;
        if PurchLine.Type <> PurchLine.Type::"Charge (Item)" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The line is not an item charge line.', 'lineNo', Format(LineNo), 'Charge (Item)', 'Pass the line no. of a Charge (Item) line.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure SalesLineOk(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; LineNo: Integer): Boolean
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        SalesHeader.SetRange("No.", DocumentNo);
        if not SalesHeader.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No document matched the request.', 'documentNo', DocumentNo, '', 'Check the document no.');
            exit(false);
        end;
        if not SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No line matched the request.', 'lineNo', Format(LineNo), '', 'Check the line no.');
            exit(false);
        end;
        if SalesLine.Type <> SalesLine.Type::"Charge (Item)" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The line is not an item charge line.', 'lineNo', Format(LineNo), 'Charge (Item)', 'Pass the line no. of a Charge (Item) line.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure WriteResponse(var Argument: Record "Message Argument ori"; DocumentType: Text; DocumentNo: Code[20]; LineNo: Integer)
    var
        ResponseJson: JsonObject;
        Rows: JsonArray;
        Unassigned: Decimal;
    begin
        if DocumentType = 'purchase' then
            Unassigned := PurchaseRows(DocumentNo, LineNo, Rows)
        else
            Unassigned := SalesRows(DocumentNo, LineNo, Rows);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.ItemCharge.Get');
        ResponseJson.Add('documentType', DocumentType);
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('lineNo', LineNo);
        ResponseJson.Add('unassignedQuantity', Unassigned);
        ResponseJson.Add('assignments', Rows);
        Argument.SetResponseJson(ResponseJson);
    end;

    local procedure PurchaseRows(DocumentNo: Code[20]; LineNo: Integer; var Rows: JsonArray): Decimal
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        Row: Record "Item Charge Assignment (Purch)";
        RowJson: JsonObject;
    begin
        PurchHeader.SetRange("No.", DocumentNo);
        PurchHeader.FindFirst();
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", LineNo);
        PurchLine.CalcFields("Qty. to Assign", "Qty. Assigned");
        Row.SetRange("Document Type", PurchHeader."Document Type");
        Row.SetRange("Document No.", PurchHeader."No.");
        Row.SetRange("Document Line No.", LineNo);
        if Row.FindSet() then
            repeat
                Clear(RowJson);
                RowJson.Add('lineNo', Row."Line No.");
                RowJson.Add('appliesToDocType', LowerCase(Format(Row."Applies-to Doc. Type")));
                RowJson.Add('appliesToDocNo', Row."Applies-to Doc. No.");
                RowJson.Add('appliesToDocLineNo', Row."Applies-to Doc. Line No.");
                RowJson.Add('itemNo', Row."Item No.");
                RowJson.Add('qtyToAssign', Row."Qty. to Assign");
                RowJson.Add('amountToAssign', Row."Amount to Assign");
                Rows.Add(RowJson);
            until Row.Next() = 0;
        exit(PurchLine.Quantity - PurchLine."Qty. to Assign" - PurchLine."Qty. Assigned");
    end;

    local procedure SalesRows(DocumentNo: Code[20]; LineNo: Integer; var Rows: JsonArray): Decimal
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Row: Record "Item Charge Assignment (Sales)";
        RowJson: JsonObject;
    begin
        SalesHeader.SetRange("No.", DocumentNo);
        SalesHeader.FindFirst();
        SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo);
        SalesLine.CalcFields("Qty. to Assign", "Qty. Assigned");
        Row.SetRange("Document Type", SalesHeader."Document Type");
        Row.SetRange("Document No.", SalesHeader."No.");
        Row.SetRange("Document Line No.", LineNo);
        if Row.FindSet() then
            repeat
                Clear(RowJson);
                RowJson.Add('lineNo', Row."Line No.");
                RowJson.Add('appliesToDocType', LowerCase(Format(Row."Applies-to Doc. Type")));
                RowJson.Add('appliesToDocNo', Row."Applies-to Doc. No.");
                RowJson.Add('appliesToDocLineNo', Row."Applies-to Doc. Line No.");
                RowJson.Add('itemNo', Row."Item No.");
                RowJson.Add('qtyToAssign', Row."Qty. to Assign");
                RowJson.Add('amountToAssign', Row."Amount to Assign");
                Rows.Add(RowJson);
            until Row.Next() = 0;
        exit(SalesLine.Quantity - SalesLine."Qty. to Assign" - SalesLine."Qty. Assigned");
    end;

    local procedure ReadDocumentNo(RequestJson: JsonObject; DocumentType: Text): Text
    var
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        SystemId: Guid;
    begin
        if RequestJson.Contains('documentNo') then
            exit(ReadText(RequestJson, 'documentNo'));
        if not Evaluate(SystemId, ReadText(RequestJson, 'systemId')) then
            exit('');
        if DocumentType = 'purchase' then begin
            if PurchHeader.GetBySystemId(SystemId) then
                exit(PurchHeader."No.");
        end else
            if SalesHeader.GetBySystemId(SystemId) then
                exit(SalesHeader."No.");
        exit('');
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, KeyName + ' is required.', CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), 'Send ' + KeyName + '.');
            exit(false);
        end;
        if (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, KeyName + ' must be text.', CopyStr(KeyName, 1, 250), '', 'text', 'Send ' + KeyName + ' as text.');
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, KeyName + ' must be text.', CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), 'text', 'Send ' + KeyName + ' as text.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Decimal;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, KeyName + ' is required.', CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), 'Send ' + KeyName + '.');
            exit(false);
        end;
        if (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, KeyName + ' must be a number.', CopyStr(KeyName, 1, 250), '', 'number', 'Send ' + KeyName + ' as a number.');
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (not Evaluate(Probe, Raw)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, KeyName + ' must be a number.', CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), 'number', 'Send ' + KeyName + ' as a number.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and (not Token.AsValue().IsNull()) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsInteger());
        exit(0);
    end;
}
