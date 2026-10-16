namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCharge.Assign. Spreads a charge line over item lines the way Item Charge Assignment does.
/// </summary>
codeunit 70013495 "Item Charge Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit(PurchAssignment.WritePermission() and SalesAssignment.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Charge Assignment (Purch)");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Assigns an item charge across purchase or sales item lines.', Comment = 'is-IS=Úthlutar vörugjaldi á vörulínur í innkaupum eða sölu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item charge, assign, freight', Comment = 'is-IS=vörugjald, úthluta, flutningsgjald';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Spread a charge by quantity, amount, weight, or volume.', Comment = 'is-IS=Dreifðu gjaldi eftir magni, upphæð, þyngd eða rúmmáli.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemCharge.Assign');
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
        Parameters.Add(ContractMgt.Parameter('method', 'string', false, 'equally, byAmount, byWeight, or byVolume.'));
        Parameters.Add(ContractMgt.Parameter('targets', 'array', false, 'Explicit target lines. Send this or method.'));
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
        Response.Add('replacedCount', 0);
        Response.Add('assignments', EmptyRows);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is missing.', 'Send documentType, lineNo, and documentNo or systemId.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong JSON type.', 'Send documentType as text and lineNo as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No document or line matched.', 'Check the document and the line no.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'documentNo and systemId were both sent, or method and targets were both sent.', 'Send one identifier and either method or targets.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The line is not a charge line.', 'Pass the line no. of a Charge (Item) line.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'A target is not an item line or belongs to another vendor or customer.', 'Use lines from the same vendor/customer.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'byWeight or byVolume was requested and the items have no weight or volume.', 'Use equally or byAmount, or fill the item''s weight/volume.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot write item charge assignments.', 'Use the BIFROST InvWrite ori permission set.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
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
        RelatedJson.Add('name', 'Inventory.ItemCharge.Get');
        RelatedJson.Add('useInsteadWhen', 'Read the current assignment instead of changing it.');
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
        Data.Add('method', 'equally');
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Assigns a purchase or sales item charge over the document item lines, or over explicit target lines.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Assigning again replaces the earlier rows for that charge line. The call does not post the document. A caller without write permission is refused. Generic record writes to the assignment tables are refused.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Runner: Codeunit "Item Charge Runner ori";
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        ClearLastError();
        if not Runner.Run(Argument) then
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, CopyStr(GetLastErrorText(), 1, 250), '', '', '', 'Check the charge line and the item lines, then try again.');
    end;

    /// <summary>
    /// Writes the assignment inside Item Charge Runner. Errors roll the write back.
    /// </summary>
    procedure RunAssign(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        DocumentType: Text;
        DocumentNo: Code[20];
        LineNo: Integer;
        Method: Text;
        Targets: JsonArray;
        HasTargets: Boolean;
        ReplacedCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        DocumentType := LowerCase(ReadText(RequestJson, 'documentType'));
        DocumentNo := CopyStr(ReadDocumentNo(RequestJson, DocumentType), 1, 20);
        LineNo := ReadInteger(RequestJson, 'lineNo');
        HasTargets := RequestJson.Contains('targets');
        if HasTargets then
            Targets := ReadArray(RequestJson, 'targets');
        Method := LowerCase(ReadText(RequestJson, 'method'));
        if DocumentType = 'purchase' then
            ReplacedCount := AssignPurchase(DocumentNo, LineNo, Method, HasTargets, Targets)
        else
            ReplacedCount := AssignSales(DocumentNo, LineNo, Method, HasTargets, Targets);
        SetAssignResponse(Argument, DocumentType, DocumentNo, LineNo, ReplacedCount);
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PurchAssignment: Record "Item Charge Assignment (Purch)";
        SalesAssignment: Record "Item Charge Assignment (Sales)";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        DomainDisabledErr: Label 'The Item Charge domain is turned off for this company.', Comment = 'is-IS=Vörugjaldssviðið er slökkt fyrir þetta fyrirtæki.';
    begin
        if (not InventorySetup.ReadPermission()) or (not PurchAssignment.WritePermission()) or (not SalesAssignment.WritePermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', 'BIFROST InvWrite ori', 'Use the BIFROST InvWrite ori permission set.');
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
        if RequestJson.Contains('method') then;
        if RequestJson.Contains('targets') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['documentType', 'documentNo', 'systemId', 'lineNo', 'method', 'targets']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key. Allowed keys are documentType, documentNo, systemId, lineNo, method and targets.');
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        DocumentType: Text;
        DocumentNo: Code[20];
        LineNo: Integer;
        Method: Text;
        HasMethod: Boolean;
        HasTargets: Boolean;
    begin
        if not RequireText(Argument, RequestJson, 'documentType') then
            exit(false);
        if not RequireInteger(Argument, RequestJson, 'lineNo') then
            exit(false);
        if not RequireIdentifier(Argument, RequestJson) then
            exit(false);
        DocumentType := LowerCase(ReadText(RequestJson, 'documentType'));
        if not (DocumentType in ['purchase', 'sales']) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'documentType must be purchase or sales.', 'documentType', CopyStr(DocumentType, 1, 250), 'purchase|sales', 'Send purchase or sales.');
            exit(false);
        end;
        DocumentNo := CopyStr(ReadDocumentNo(RequestJson, DocumentType), 1, 20);
        if DocumentNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'No document matched the request.', 'documentNo', '', '', 'Check the document no.');
            exit(false);
        end;
        LineNo := ReadInteger(RequestJson, 'lineNo');
        HasMethod := RequestJson.Contains('method');
        HasTargets := RequestJson.Contains('targets');
        if HasMethod and HasTargets then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send method or targets, not both.', 'method', '', 'targets', 'Send method or targets, not both.');
            exit(false);
        end;
        if (not HasMethod) and (not HasTargets) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'method or targets is required.', 'method', '', 'method', 'Send method or targets.');
            exit(false);
        end;
        if HasMethod then begin
            if not RequireText(Argument, RequestJson, 'method') then
                exit(false);
            Method := LowerCase(ReadText(RequestJson, 'method'));
            if not (Method in ['equally', 'byamount', 'byweight', 'byvolume']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'method is not supported.', 'method', CopyStr(Method, 1, 250), 'equally|byAmount|byWeight|byVolume', 'Use equally, byAmount, byWeight or byVolume.');
                exit(false);
            end;
        end else
            if not RequireArray(Argument, RequestJson, 'targets') then
                exit(false);
        if DocumentType = 'purchase' then
            exit(ValidatePurchase(Argument, DocumentNo, LineNo, Method, HasTargets, RequestJson));
        exit(ValidateSales(Argument, DocumentNo, LineNo, Method, HasTargets, RequestJson));
    end;

    local procedure ValidatePurchase(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; LineNo: Integer; Method: Text; HasTargets: Boolean; RequestJson: JsonObject): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
    begin
        if not FindPurchaseHeader(DocumentNo, PurchHeader) then begin
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
        if PurchLine."Qty. to Invoice" = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The charge line has no quantity to invoice.', 'lineNo', Format(LineNo), '', 'Set a quantity to invoice on the charge line.');
            exit(false);
        end;
        if HasTargets then
            exit(ValidatePurchaseTargets(Argument, PurchHeader, ReadArray(RequestJson, 'targets')));
        if not HasPurchaseItemLines(PurchHeader) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'The document has no item line to assign.', 'documentNo', PurchHeader."No.", '', 'Add an item line to the document.');
            exit(false);
        end;
        exit(ValidatePurchaseMeasure(Argument, PurchHeader, Method));
    end;

    local procedure ValidateSales(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; LineNo: Integer; Method: Text; HasTargets: Boolean; RequestJson: JsonObject): Boolean
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        if not FindSalesHeader(DocumentNo, SalesHeader) then begin
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
        if SalesLine."Qty. to Invoice" = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The charge line has no quantity to invoice.', 'lineNo', Format(LineNo), '', 'Set a quantity to invoice on the charge line.');
            exit(false);
        end;
        if HasTargets then
            exit(ValidateSalesTargets(Argument, SalesHeader, ReadArray(RequestJson, 'targets')));
        if not HasSalesItemLines(SalesHeader) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'The document has no item line to assign.', 'documentNo', SalesHeader."No.", '', 'Add an item line to the document.');
            exit(false);
        end;
        exit(ValidateSalesMeasure(Argument, SalesHeader, Method));
    end;

    local procedure ValidatePurchaseMeasure(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; Method: Text): Boolean
    var
        ItemLine: Record "Purchase Line";
        Item: Record Item;
        TotalWeight: Decimal;
        TotalVolume: Decimal;
    begin
        if not (Method in ['byweight', 'byvolume']) then
            exit(true);
        ItemLine.SetRange("Document Type", PurchHeader."Document Type");
        ItemLine.SetRange("Document No.", PurchHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        if ItemLine.FindSet() then
            repeat
                if Item.Get(ItemLine."No.") then begin
                    TotalWeight += Item."Gross Weight" * ItemLine.Quantity;
                    TotalVolume += Item."Unit Volume" * ItemLine.Quantity;
                end;
            until ItemLine.Next() = 0;
        exit(MeasureOk(Argument, Method, TotalWeight, TotalVolume));
    end;

    local procedure ValidateSalesMeasure(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; Method: Text): Boolean
    var
        ItemLine: Record "Sales Line";
        Item: Record Item;
        TotalWeight: Decimal;
        TotalVolume: Decimal;
    begin
        if not (Method in ['byweight', 'byvolume']) then
            exit(true);
        ItemLine.SetRange("Document Type", SalesHeader."Document Type");
        ItemLine.SetRange("Document No.", SalesHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        if ItemLine.FindSet() then
            repeat
                if Item.Get(ItemLine."No.") then begin
                    TotalWeight += Item."Gross Weight" * ItemLine.Quantity;
                    TotalVolume += Item."Unit Volume" * ItemLine.Quantity;
                end;
            until ItemLine.Next() = 0;
        exit(MeasureOk(Argument, Method, TotalWeight, TotalVolume));
    end;

    local procedure MeasureOk(var Argument: Record "Message Argument ori"; Method: Text; TotalWeight: Decimal; TotalVolume: Decimal): Boolean
    var
        MeasureErr: Label 'The items have no weight or volume to assign by.', Comment = 'is-IS=Vörurnar hafa enga þyngd eða rúmmál til að úthluta eftir.';
    begin
        if (Method = 'byweight') and (TotalWeight = 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, MeasureErr, 'method', 'byWeight', 'equally|byAmount', 'Use equally or byAmount, or fill the item''s weight/volume.');
            exit(false);
        end;
        if (Method = 'byvolume') and (TotalVolume = 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, MeasureErr, 'method', 'byVolume', 'equally|byAmount', 'Use equally or byAmount, or fill the item''s weight/volume.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure ValidatePurchaseTargets(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; Targets: JsonArray): Boolean
    var
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
    begin
        if Targets.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'targets must contain a line.', 'targets', '', 'targets', 'Send at least one target.');
            exit(false);
        end;
        foreach TargetToken in Targets do begin
            if not TargetToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'Each target must be an object.', 'targets', '', 'object', 'Send each target as an object.');
                exit(false);
            end;
            Target := TargetToken.AsObject();
            if not RequireText(Argument, Target, 'appliesToDocType') then
                exit(false);
            if not RequireText(Argument, Target, 'documentNo') then
                exit(false);
            if not RequireInteger(Argument, Target, 'lineNo') then
                exit(false);
            if not RequireDecimal(Argument, Target, 'qtyToAssign') then
                exit(false);
            AppliesTo := LowerCase(ReadText(Target, 'appliesToDocType'));
            TargetNo := CopyStr(ReadText(Target, 'documentNo'), 1, 20);
            TargetLineNo := ReadInteger(Target, 'lineNo');
            if not PurchaseTargetOk(Argument, PurchHeader, AppliesTo, TargetNo, TargetLineNo) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateSalesTargets(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; Targets: JsonArray): Boolean
    var
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
    begin
        if Targets.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'targets must contain a line.', 'targets', '', 'targets', 'Send at least one target.');
            exit(false);
        end;
        foreach TargetToken in Targets do begin
            if not TargetToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'Each target must be an object.', 'targets', '', 'object', 'Send each target as an object.');
                exit(false);
            end;
            Target := TargetToken.AsObject();
            if not RequireText(Argument, Target, 'appliesToDocType') then
                exit(false);
            if not RequireText(Argument, Target, 'documentNo') then
                exit(false);
            if not RequireInteger(Argument, Target, 'lineNo') then
                exit(false);
            if not RequireDecimal(Argument, Target, 'qtyToAssign') then
                exit(false);
            AppliesTo := LowerCase(ReadText(Target, 'appliesToDocType'));
            TargetNo := CopyStr(ReadText(Target, 'documentNo'), 1, 20);
            TargetLineNo := ReadInteger(Target, 'lineNo');
            if not SalesTargetOk(Argument, SalesHeader, AppliesTo, TargetNo, TargetLineNo) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure PurchaseTargetOk(var Argument: Record "Message Argument ori"; PurchHeader: Record "Purchase Header"; AppliesTo: Text; TargetNo: Code[20]; TargetLineNo: Integer): Boolean
    var
        PurchLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        InvalidLineErr: Label 'The target line cannot take this item charge.', Comment = 'is-IS=Marklínan getur ekki tekið við þessu vörugjaldi.';
    begin
        case AppliesTo of
            'order':
                begin
                    if not PurchLine.Get(PurchLine."Document Type"::Order, TargetNo, TargetLineNo) then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if PurchLine.Type <> PurchLine.Type::Item then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if PurchLine."Buy-from Vendor No." <> PurchHeader."Buy-from Vendor No." then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                end;
            'receipt':
                begin
                    if not PurchRcptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if PurchRcptLine.Type <> PurchRcptLine.Type::Item then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    PurchRcptHeader.Get(TargetNo);
                    if PurchRcptHeader."Buy-from Vendor No." <> PurchHeader."Buy-from Vendor No." then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                end;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'appliesToDocType is not supported for a purchase charge.', 'appliesToDocType', CopyStr(AppliesTo, 1, 250), 'order|receipt', 'Use order or receipt.');
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure SalesTargetOk(var Argument: Record "Message Argument ori"; SalesHeader: Record "Sales Header"; AppliesTo: Text; TargetNo: Code[20]; TargetLineNo: Integer): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
        SalesShptHeader: Record "Sales Shipment Header";
        InvalidLineErr: Label 'The target line cannot take this item charge.', Comment = 'is-IS=Marklínan getur ekki tekið við þessu vörugjaldi.';
    begin
        case AppliesTo of
            'order':
                begin
                    if not SalesLine.Get(SalesLine."Document Type"::Order, TargetNo, TargetLineNo) then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if SalesLine.Type <> SalesLine.Type::Item then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if SalesLine."Sell-to Customer No." <> SalesHeader."Sell-to Customer No." then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                end;
            'shipment':
                begin
                    if not SalesShptLine.Get(TargetNo, TargetLineNo) then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    if SalesShptLine.Type <> SalesShptLine.Type::Item then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                    SalesShptHeader.Get(TargetNo);
                    if SalesShptHeader."Sell-to Customer No." <> SalesHeader."Sell-to Customer No." then
                        exit(RespondInvalidLine(Argument, InvalidLineErr));
                end;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'appliesToDocType is not supported for a sales charge.', 'appliesToDocType', CopyStr(AppliesTo, 1, 250), 'order|shipment', 'Use order or shipment.');
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure RespondInvalidLine(var Argument: Record "Message Argument ori"; InvalidLineErr: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidLine, CopyStr(InvalidLineErr, 1, 250), 'targets', '', '', 'Use lines from the same vendor/customer.');
        exit(false);
    end;

    local procedure AssignPurchase(DocumentNo: Code[20]; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray): Integer
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        Existing: Record "Item Charge Assignment (Purch)";
        ChargeAssgnt: Record "Item Charge Assignment (Purch)";
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
        ReplacedCount: Integer;
        NextLineNo: Integer;
        Qty: Decimal;
    begin
        FindPurchaseHeader(DocumentNo, PurchHeader);
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", LineNo);
        Existing.SetRange("Document Type", PurchLine."Document Type");
        Existing.SetRange("Document No.", PurchLine."Document No.");
        Existing.SetRange("Document Line No.", PurchLine."Line No.");
        ReplacedCount := Existing.Count();
        Existing.DeleteAll(true);
        ChargeAssgnt.Init();
        ChargeAssgnt."Document Type" := PurchLine."Document Type";
        ChargeAssgnt."Document No." := PurchLine."Document No.";
        ChargeAssgnt."Document Line No." := PurchLine."Line No.";
        ChargeAssgnt."Item Charge No." := PurchLine."No.";
        ChargeAssgnt."Unit Cost" := PurchLine."Direct Unit Cost";
        if HasTargets then
            InsertPurchaseTargets(ChargeAssgnt, Targets, NextLineNo)
        else begin
            AssignPurch.CreateDocChargeAssgnt(ChargeAssgnt, '');
            Qty := PurchLine."Qty. to Invoice";
            AssignPurch.AssignItemCharges(PurchLine, Qty, Qty * PurchLine."Direct Unit Cost", Qty, Qty * PurchLine."Direct Unit Cost", PurchaseSelection(Method));
        end;
        exit(ReplacedCount);
    end;

    local procedure AssignSales(DocumentNo: Code[20]; LineNo: Integer; Method: Text; HasTargets: Boolean; Targets: JsonArray): Integer
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Existing: Record "Item Charge Assignment (Sales)";
        ChargeAssgnt: Record "Item Charge Assignment (Sales)";
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
        ReplacedCount: Integer;
        NextLineNo: Integer;
        Qty: Decimal;
    begin
        FindSalesHeader(DocumentNo, SalesHeader);
        SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo);
        Existing.SetRange("Document Type", SalesLine."Document Type");
        Existing.SetRange("Document No.", SalesLine."Document No.");
        Existing.SetRange("Document Line No.", SalesLine."Line No.");
        ReplacedCount := Existing.Count();
        Existing.DeleteAll(true);
        ChargeAssgnt.Init();
        ChargeAssgnt."Document Type" := SalesLine."Document Type";
        ChargeAssgnt."Document No." := SalesLine."Document No.";
        ChargeAssgnt."Document Line No." := SalesLine."Line No.";
        ChargeAssgnt."Item Charge No." := SalesLine."No.";
        ChargeAssgnt."Unit Cost" := SalesLine."Unit Price";
        if HasTargets then
            InsertSalesTargets(ChargeAssgnt, Targets, NextLineNo)
        else begin
            AssignSalesCu.CreateDocChargeAssgn(ChargeAssgnt, '');
            Qty := SalesLine."Qty. to Invoice";
            AssignSalesCu.AssignItemCharges(SalesLine, Qty, Qty * SalesLine."Unit Price", Qty, Qty * SalesLine."Unit Price", SalesSelection(Method));
        end;
        exit(ReplacedCount);
    end;

    local procedure InsertPurchaseTargets(ChargeAssgnt: Record "Item Charge Assignment (Purch)"; Targets: JsonArray; var NextLineNo: Integer)
    var
        PurchLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
        Qty: Decimal;
    begin
        foreach TargetToken in Targets do begin
            Target := TargetToken.AsObject();
            AppliesTo := LowerCase(ReadText(Target, 'appliesToDocType'));
            TargetNo := CopyStr(ReadText(Target, 'documentNo'), 1, 20);
            TargetLineNo := ReadInteger(Target, 'lineNo');
            Qty := ReadDecimal(Target, 'qtyToAssign');
            if AppliesTo = 'order' then begin
                PurchLine.Get(PurchLine."Document Type"::Order, TargetNo, TargetLineNo);
                AssignPurch.InsertItemChargeAssignmentWithValues(ChargeAssgnt, Enum::"Purchase Applies-to Document Type"::Order, TargetNo, TargetLineNo, PurchLine."No.", PurchLine.Description, Qty, 0, NextLineNo);
            end else begin
                PurchRcptLine.Get(TargetNo, TargetLineNo);
                AssignPurch.InsertItemChargeAssignmentWithValues(ChargeAssgnt, Enum::"Purchase Applies-to Document Type"::Receipt, TargetNo, TargetLineNo, PurchRcptLine."No.", PurchRcptLine.Description, Qty, 0, NextLineNo);
            end;
        end;
    end;

    local procedure InsertSalesTargets(ChargeAssgnt: Record "Item Charge Assignment (Sales)"; Targets: JsonArray; var NextLineNo: Integer)
    var
        SalesLine: Record "Sales Line";
        SalesShptLine: Record "Sales Shipment Line";
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
        TargetToken: JsonToken;
        Target: JsonObject;
        AppliesTo: Text;
        TargetNo: Code[20];
        TargetLineNo: Integer;
        Qty: Decimal;
    begin
        foreach TargetToken in Targets do begin
            Target := TargetToken.AsObject();
            AppliesTo := LowerCase(ReadText(Target, 'appliesToDocType'));
            TargetNo := CopyStr(ReadText(Target, 'documentNo'), 1, 20);
            TargetLineNo := ReadInteger(Target, 'lineNo');
            Qty := ReadDecimal(Target, 'qtyToAssign');
            if AppliesTo = 'order' then begin
                SalesLine.Get(SalesLine."Document Type"::Order, TargetNo, TargetLineNo);
                AssignSalesCu.InsertItemChargeAssignmentWithValues(ChargeAssgnt, Enum::"Sales Applies-to Document Type"::Order, TargetNo, TargetLineNo, SalesLine."No.", SalesLine.Description, Qty, 0, NextLineNo);
            end else begin
                SalesShptLine.Get(TargetNo, TargetLineNo);
                AssignSalesCu.InsertItemChargeAssignmentWithValues(ChargeAssgnt, Enum::"Sales Applies-to Document Type"::Shipment, TargetNo, TargetLineNo, SalesShptLine."No.", SalesShptLine.Description, Qty, 0, NextLineNo);
            end;
        end;
    end;

    local procedure PurchaseSelection(Method: Text): Text
    var
        AssignPurch: Codeunit "Item Charge Assgnt. (Purch.)";
    begin
        case Method of
            'byamount':
                exit(AssignPurch.AssignByAmountMenuText());
            'byweight':
                exit(AssignPurch.AssignByWeightMenuText());
            'byvolume':
                exit(AssignPurch.AssignByVolumeMenuText());
            else
                exit(AssignPurch.AssignEquallyMenuText());
        end;
    end;

    local procedure SalesSelection(Method: Text): Text
    var
        AssignSalesCu: Codeunit "Item Charge Assgnt. (Sales)";
    begin
        case Method of
            'byamount':
                exit(AssignSalesCu.AssignByAmountMenuText());
            'byweight':
                exit(AssignSalesCu.AssignByWeightMenuText());
            'byvolume':
                exit(AssignSalesCu.AssignByVolumeMenuText());
            else
                exit(AssignSalesCu.AssignEquallyMenuText());
        end;
    end;

    local procedure SetAssignResponse(var Argument: Record "Message Argument ori"; DocumentType: Text; DocumentNo: Code[20]; LineNo: Integer; ReplacedCount: Integer)
    var
        ResponseJson: JsonObject;
        Rows: JsonArray;
    begin
        if DocumentType = 'purchase' then
            Rows := PurchaseRows(DocumentNo, LineNo)
        else
            Rows := SalesRows(DocumentNo, LineNo);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.ItemCharge.Assign');
        ResponseJson.Add('documentType', DocumentType);
        ResponseJson.Add('documentNo', DocumentNo);
        ResponseJson.Add('lineNo', LineNo);
        ResponseJson.Add('replacedCount', ReplacedCount);
        ResponseJson.Add('assignments', Rows);
        Argument.SetResponseJson(ResponseJson);
    end;

    local procedure PurchaseRows(DocumentNo: Code[20]; LineNo: Integer) Rows: JsonArray
    var
        PurchHeader: Record "Purchase Header";
        Row: Record "Item Charge Assignment (Purch)";
        RowJson: JsonObject;
    begin
        FindPurchaseHeader(DocumentNo, PurchHeader);
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
    end;

    local procedure SalesRows(DocumentNo: Code[20]; LineNo: Integer) Rows: JsonArray
    var
        SalesHeader: Record "Sales Header";
        Row: Record "Item Charge Assignment (Sales)";
        RowJson: JsonObject;
    begin
        FindSalesHeader(DocumentNo, SalesHeader);
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
    end;

    local procedure HasPurchaseItemLines(PurchHeader: Record "Purchase Header"): Boolean
    var
        ItemLine: Record "Purchase Line";
    begin
        ItemLine.SetRange("Document Type", PurchHeader."Document Type");
        ItemLine.SetRange("Document No.", PurchHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.SetFilter(Quantity, '<>0');
        exit(not ItemLine.IsEmpty());
    end;

    local procedure HasSalesItemLines(SalesHeader: Record "Sales Header"): Boolean
    var
        ItemLine: Record "Sales Line";
    begin
        ItemLine.SetRange("Document Type", SalesHeader."Document Type");
        ItemLine.SetRange("Document No.", SalesHeader."No.");
        ItemLine.SetRange(Type, ItemLine.Type::Item);
        ItemLine.SetFilter(Quantity, '<>0');
        exit(not ItemLine.IsEmpty());
    end;

    local procedure FindPurchaseHeader(DocumentNo: Code[20]; var PurchHeader: Record "Purchase Header"): Boolean
    begin
        PurchHeader.SetRange("No.", DocumentNo);
        exit(PurchHeader.FindFirst());
    end;

    local procedure FindSalesHeader(DocumentNo: Code[20]; var SalesHeader: Record "Sales Header"): Boolean
    begin
        SalesHeader.SetRange("No.", DocumentNo);
        exit(SalesHeader.FindFirst());
    end;

    local procedure ReadDocumentNo(RequestJson: JsonObject; DocumentType: Text): Text
    var
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        SystemId: Guid;
    begin
        if RequestJson.Contains('documentNo') then
            exit(ReadText(RequestJson, 'documentNo'));
        if not RequestJson.Contains('systemId') then
            exit('');
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

    local procedure RequireIdentifier(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    begin
        if RequestJson.Contains('documentNo') and RequestJson.Contains('systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send documentNo or systemId, not both.', 'documentNo', '', 'systemId', 'Send documentNo or systemId, not both.');
            exit(false);
        end;
        if (not RequestJson.Contains('documentNo')) and (not RequestJson.Contains('systemId')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentNo or systemId is required.', 'documentNo', '', 'documentNo', 'Send documentNo or systemId.');
            exit(false);
        end;
        if RequestJson.Contains('documentNo') then
            exit(RequireText(Argument, RequestJson, 'documentNo'));
        exit(RequireText(Argument, RequestJson, 'systemId'));
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

    local procedure RequireDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    begin
        exit(RequireInteger(Argument, RequestJson, KeyName));
    end;

    local procedure RequireArray(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, KeyName + ' is required.', CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), 'Send ' + KeyName + '.');
            exit(false);
        end;
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, KeyName + ' must be an array.', CopyStr(KeyName, 1, 250), '', 'array', 'Send ' + KeyName + ' as an array.');
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

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsDecimal());
        exit(0);
    end;

    local procedure ReadArray(RequestJson: JsonObject; KeyName: Text): JsonArray
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsArray() then
            exit(Token.AsArray());
    end;
}
