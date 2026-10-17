namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.OrderTracking.Get reads the supply and demand tracked against one line or item ledger entry.
/// </summary>
codeunit 70013431 "Order Tracking Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        ReservationEntry: Record "Reservation Entry";
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not ReservationEntry.ReadPermission() then
            exit(false);
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads the order tracking chain for a line.', Comment = 'is-IS=Les rakningarkeðju pöntunar fyrir línu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'order tracking, supply, demand', Comment = 'is-IS=pöntunarrakning, framboð, eftirspurn';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads which supply is tracked against a demand line.', Comment = 'is-IS=Les hvaða framboð er rakið við eftirspurnarlínu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.OrderTracking.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Order Tracking Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'sourceKind');
        ParameterJson.Add('type', 'text');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentType');
        ParameterJson.Add('type', 'text');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lineNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'systemId');
        ParameterJson.Add('type', 'guid');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'entryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('entries', 'array');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'sourceKind is missing.', 'Send sourceKind.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'sourceKind is not Sales, Purchase, Transfer, Assembly or ItemLedgerEntry.', 'Send a supported sourceKind.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong type.', 'Send lineNo and entryNo as integers, and systemId as a GUID.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'systemId was sent with document keys.', 'Send systemId or the document keys, not both.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The source line was not found.', 'Check the document and line no.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read reservation entries.', 'Use the BIFROST InvRead ori permission set.'));
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
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.AutoReserve', 'Reserve a sales line before reading its tracking chain.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read reservation entries for an item.'));
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
        Data.Add('sourceKind', 'Sales');
        Data.Add('documentType', 'Order');
        Data.Add('documentNo', '101005');
        Data.Add('lineNo', 10000);
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads the order tracking chain for a sales, purchase, transfer or assembly line, or for one item ledger entry. Each entry names the supply, the demand, the quantity and the dates. This call does not create or change reservations.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        InventorySetup: Record "Inventory Setup ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Entries: JsonArray;
        SourceRecord: Variant;
    begin
        if not ReservationEntry.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, 'Permission denied for this inventory message type.', '', '', '', 'Use the BIFROST InvRead ori permission set.');
            exit;
        end;
        if not InventorySetup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, 'Permission denied for this inventory message type.', '', '', '', 'Use the BIFROST InvRead ori permission set.');
            exit;
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'The Reservations domain is turned off for this company.', 'domain', 'Reservations', 'on', 'Turn the domain on from the Inventory Setup page.');
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if not BindSource(Argument, RequestJson, SourceRecord) then
            exit;
        Entries := TrackingEntries(SourceRecord);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        SourceKind: Text;
        HasSystemId: Boolean;
        HasDocumentKeys: Boolean;
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['sourceKind', 'documentType', 'documentNo', 'lineNo', 'systemId', 'entryNo']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key.');
                exit(false);
            end;
        if not RequestJson.Contains('sourceKind') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'sourceKind is required.', 'sourceKind', '', 'Sales', 'Send sourceKind.');
            exit(false);
        end;
        SourceKind := UpperCase(ReadText(RequestJson, 'sourceKind'));
        if not (SourceKind in ['SALES', 'PURCHASE', 'TRANSFER', 'ASSEMBLY', 'ITEMLEDGERENTRY']) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, 'sourceKind is not supported.', 'sourceKind', ReadText(RequestJson, 'sourceKind'), 'Sales, Purchase, Transfer, Assembly or ItemLedgerEntry', 'Send a supported sourceKind.');
            exit(false);
        end;
        HasSystemId := RequestJson.Contains('systemId');
        HasDocumentKeys := RequestJson.Contains('documentType') or RequestJson.Contains('documentNo') or RequestJson.Contains('lineNo') or RequestJson.Contains('entryNo');
        if HasSystemId and HasDocumentKeys then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send systemId or the document keys, not both.', 'systemId', '', 'documentNo', 'Send systemId or the document keys, not both.');
            exit(false);
        end;
        if SourceKind = 'ITEMLEDGERENTRY' then begin
            if not RequestJson.Contains('entryNo') and not HasSystemId then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'entryNo is required.', 'entryNo', '', 'an item ledger entry number', 'Send entryNo.');
                exit(false);
            end;
        end else
            if not HasSystemId and not RequestJson.Contains('documentNo') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'documentNo is required.', 'documentNo', '', 'a document number', 'Check the document and line no.');
                exit(false);
            end;
        if RequestJson.Contains('lineNo') and not IsInteger(RequestJson, 'lineNo') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'lineNo must be an integer.', 'lineNo', ReadText(RequestJson, 'lineNo'), 'an integer', 'Send lineNo as an integer.');
            exit(false);
        end;
        if RequestJson.Contains('entryNo') and not IsInteger(RequestJson, 'entryNo') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'entryNo must be an integer.', 'entryNo', ReadText(RequestJson, 'entryNo'), 'an integer', 'Send entryNo as an integer.');
            exit(false);
        end;
        if HasSystemId and not IsGuid(RequestJson, 'systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'systemId must be a GUID.', 'systemId', ReadText(RequestJson, 'systemId'), 'a GUID', 'Send systemId as a GUID.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure BindSource(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        SourceKind: Text;
    begin
        SourceKind := UpperCase(ReadText(RequestJson, 'sourceKind'));
        case SourceKind of
            'SALES':
                exit(BindSales(Argument, RequestJson, SourceRecord));
            'PURCHASE':
                exit(BindPurchase(Argument, RequestJson, SourceRecord));
            'TRANSFER':
                exit(BindTransfer(Argument, RequestJson, SourceRecord));
            'ASSEMBLY':
                exit(BindAssembly(Argument, RequestJson, SourceRecord));
            'ITEMLEDGERENTRY':
                exit(BindLedger(Argument, RequestJson, SourceRecord));
        end;
        exit(false);
    end;

    local procedure BindSales(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        SalesLine: Record "Sales Line";
        LineId: Guid;
        DocumentType: Enum "Sales Document Type";
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then begin
            if not SalesLine.GetBySystemId(LineId) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end else begin
            if not ReadSalesDocumentType(ReadText(RequestJson, 'documentType'), DocumentType) then
                DocumentType := DocumentType::Order;
            if not SalesLine.Get(DocumentType, CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(SalesLine."Document No.")), ReadInteger(RequestJson, 'lineNo')) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end;
        SourceRecord := SalesLine;
        exit(true);
    end;

    local procedure BindPurchase(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        PurchaseLine: Record "Purchase Line";
        LineId: Guid;
        DocumentType: Enum "Purchase Document Type";
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then begin
            if not PurchaseLine.GetBySystemId(LineId) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end else begin
            if not ReadPurchaseDocumentType(ReadText(RequestJson, 'documentType'), DocumentType) then
                DocumentType := DocumentType::Order;
            if not PurchaseLine.Get(DocumentType, CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(PurchaseLine."Document No.")), ReadInteger(RequestJson, 'lineNo')) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end;
        SourceRecord := PurchaseLine;
        exit(true);
    end;

    local procedure BindTransfer(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        TransferLine: Record "Transfer Line";
        LineId: Guid;
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then begin
            if not TransferLine.GetBySystemId(LineId) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end else
            if not TransferLine.Get(CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(TransferLine."Document No.")), ReadInteger(RequestJson, 'lineNo')) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        SourceRecord := TransferLine;
        exit(true);
    end;

    local procedure BindAssembly(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        AssemblyLine: Record "Assembly Line";
        LineId: Guid;
        DocumentType: Enum "Assembly Document Type";
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then begin
            if not AssemblyLine.GetBySystemId(LineId) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end else begin
            DocumentType := DocumentType::Order;
            if not AssemblyLine.Get(DocumentType, CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(AssemblyLine."Document No.")), ReadInteger(RequestJson, 'lineNo')) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end;
        SourceRecord := AssemblyLine;
        exit(true);
    end;

    local procedure BindLedger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var SourceRecord: Variant): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        LineId: Guid;
    begin
        if ReadGuid(RequestJson, 'systemId', LineId) then begin
            if not ItemLedgerEntry.GetBySystemId(LineId) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        end else
            if not ItemLedgerEntry.Get(ReadInteger(RequestJson, 'entryNo')) then begin
                RespondNotFound(Argument);
                exit(false);
            end;
        SourceRecord := ItemLedgerEntry;
        exit(true);
    end;

    local procedure TrackingEntries(var SourceRecord: Variant) Entries: JsonArray
    var
        OrderTrackingEntry: Record "Order Tracking Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        OrderTrackingManagement: Codeunit OrderTrackingManagement;
        SourceRef: RecordRef;
        EntryJson: JsonObject;
    begin
        SourceRef.GetTable(SourceRecord);
        if SourceRef.Number = Database::"Item Ledger Entry" then begin
            ItemLedgerEntry := SourceRecord;
            OrderTrackingManagement.SetItemLedgEntry(ItemLedgerEntry);
        end else
            // Transfer lines have no OnSetSourceRecord subscriber in the base app, so the chain stays empty.
            OrderTrackingManagement.SetSourceRecord(SourceRecord);
        if not OrderTrackingManagement.FindRecordsWithoutMessage() then
            exit;
        if not OrderTrackingManagement.FindRecord('-', OrderTrackingEntry) then
            exit;
        repeat
            if OrderTrackingEntry."Entry No." <> 0 then begin
                Clear(EntryJson);
                EntryJson.Add('suppliedBy', OrderTrackingEntry."Supplied by");
                EntryJson.Add('demandedBy', OrderTrackingEntry."Demanded by");
                EntryJson.Add('quantity', OrderTrackingEntry.Quantity);
                EntryJson.Add('shipmentDate', Format(OrderTrackingEntry."Shipment Date", 0, 9));
                EntryJson.Add('expectedReceiptDate', Format(OrderTrackingEntry."Expected Receipt Date", 0, 9));
                EntryJson.Add('itemNo', OrderTrackingEntry."Item No.");
                EntryJson.Add('forType', OrderTrackingEntry."For Type");
                EntryJson.Add('forId', OrderTrackingEntry."For ID");
                EntryJson.Add('forRefNo', OrderTrackingEntry."For Ref. No.");
                EntryJson.Add('fromType', OrderTrackingEntry."From Type");
                EntryJson.Add('fromId', OrderTrackingEntry."From ID");
                EntryJson.Add('fromRefNo', OrderTrackingEntry."From Ref. No.");
                Entries.Add(EntryJson);
            end;
        until OrderTrackingManagement.GetNextRecord(1, OrderTrackingEntry) = 0;
    end;

    local procedure RespondNotFound(var Argument: Record "Message Argument ori")
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, 'The source line was not found.', 'documentNo', '', 'an existing line', 'Check the document and line no.');
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

    local procedure ReadPurchaseDocumentType(DocumentTypeText: Text; var DocumentType: Enum "Purchase Document Type"): Boolean
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

    local procedure IsInteger(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Result: Integer;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;

    local procedure IsGuid(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Result: Guid;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
    end;

    local procedure ReadGuid(RequestJson: JsonObject; KeyName: Text; var Result: Guid): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) or not Token.IsValue() then
            exit(false);
        exit(Evaluate(Result, Token.AsValue().AsText()));
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

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
