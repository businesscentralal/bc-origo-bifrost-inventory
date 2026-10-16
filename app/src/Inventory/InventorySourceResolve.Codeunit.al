namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Resolves sales, purchase and transfer sources for read-only tracking projection.</summary>
codeunit 10036913 "Inventory Source Resolve ori"
{
    Access = Internal;

    /// <summary>Resolves an explicit source object by type and SystemId, checking source permissions before use.</summary>
    procedure Resolve(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; NeedWrite: Boolean; var SourceRef: RecordRef; var Specification: Record "Tracking Specification"; var Direction: Enum "Transfer Direction"): Boolean
    var
        Source: JsonObject;
        Token: JsonToken;
        TypeName: Text;
        IdText: Text;
        DirectionText: Text;
        SourceId: Guid;
        TableNo: Integer;
        InvalidSourceErr: Label 'Specify %1 with a supported type and systemId.', Comment = '%1 = request property, is-IS=Tilgreindu %1 með studdri tegund og systemId.';
        MissingSourceErr: Label 'The requested source record does not exist.', Comment = 'is-IS=Umbeðin upprunafærsla er ekki til.';
        PermissionErr: Label 'Permission denied for the source record.', Comment = 'is-IS=Heimild hafnað fyrir upprunafærsluna.';
    begin
        Clear(Specification);
        Direction := Direction::Outbound;
        if not Request.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName, '', 'object', '');
            exit(false);
        end;
        if not Token.IsObject() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidSourceErr, KeyName), KeyName, '', 'object', '');
            exit(false);
        end;
        Source := Token.AsObject();
        if not ReadText(Argument, Source, 'type', true, TypeName) then
            exit(false);
        TableNo := SourceTableNo(TypeName);
        if TableNo = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.type', TypeName, '', '');
            exit(false);
        end;
        if not ReadText(Argument, Source, 'systemId', true, IdText) then
            exit(false);
        if not Evaluate(SourceId, IdText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.systemId', IdText, 'guid', '');
            exit(false);
        end;
        if not ReadText(Argument, Source, 'transferDirection', false, DirectionText) then
            exit(false);
        case DirectionText of
            '', 'Outbound':;
            'Inbound':
                Direction := Direction::Inbound;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.transferDirection', DirectionText, 'Outbound|Inbound', '');
                exit(false);
            end;
        end;
        SourceRef.Open(TableNo);
        if not SourceRef.ReadPermission() or (NeedWrite and (TableNo <> Database::"Item Ledger Entry") and not SourceRef.WritePermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, KeyName, '', '', '');
            exit(false);
        end;
        // Full-record by native contract: InitFromSalesLine, InitFromPurchLine or InitFromTransLine consumes this record.
        if not SourceRef.GetBySystemId(SourceId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingSourceErr, KeyName + '.systemId', IdText, '', '');
            exit(false);
        end;
        InitializeSpecification(SourceRef, Direction, Specification);
        exit(true);
    end;

    /// <summary>Resolves legacy document keys through the same permission-checked native source adapter.</summary>
    procedure ResolveDocument(var Argument: Record "Message Argument ori"; Request: JsonObject; NeedWrite: Boolean; var SourceRef: RecordRef; var Specification: Record "Tracking Specification"; var Direction: Enum "Transfer Direction"): Boolean
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        Reader: Codeunit "Request Value Reader ori";
        PermissionRef: RecordRef;
        DocumentType: Text;
        DocumentNo: Text;
        IdText: Text;
        TypeName: Text;
        Subtype: Integer;
        LineNo: Decimal;
        Found: Boolean;
        Source: JsonObject;
        SourceRequest: JsonObject;
        Token: JsonToken;
        DocumentErr: Label 'Specify a supported document type and an existing item line.', Comment = 'is-IS=Tilgreindu studda skjalategund og fyrirliggjandi vörulínu.';
        PermissionErr: Label 'Permission denied for the source record.', Comment = 'is-IS=Heimild hafnað fyrir upprunafærsluna.';
    begin
        if Request.Contains('source') then
            exit(Resolve(Argument, Request, 'source', NeedWrite, SourceRef, Specification, Direction));
        if not ReadText(Argument, Request, 'documentType', true, DocumentType) then
            exit(false);
        case DocumentType of
            'Order', 'Sales.Order': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::Order.AsInteger();
            end;
            'Invoice', 'Sales.Invoice': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::Invoice.AsInteger();
            end;
            'Credit Memo', 'Sales.CreditMemo': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::"Credit Memo".AsInteger();
            end;
            'Return Order', 'Sales.ReturnOrder': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::"Return Order".AsInteger();
            end;
            'Purchase.Order': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::Order.AsInteger();
            end;
            'Purchase.Invoice': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::Invoice.AsInteger();
            end;
            'Purchase.CreditMemo': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::"Credit Memo".AsInteger();
            end;
            'Purchase.ReturnOrder': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::"Return Order".AsInteger();
            end;
            'Transfer.Order':
                TypeName := 'TransferLine';
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentErr, 'documentType', DocumentType, '', '');
                exit(false);
            end;
        end;
        Source.Add('type', TypeName);
        if not ReadText(Argument, Request, 'systemId', false, IdText) then
            exit(false);
        if IdText = '' then begin
            if not ReadText(Argument, Request, 'documentNo', true, DocumentNo) then
                exit(false);
            if not Reader.TryReadDecimal(Argument, Request, 'lineNo', true, LineNo) then
                exit(false);
            if (StrLen(DocumentNo) > 20) or (LineNo <= 0) or (LineNo > 2147483647) or (LineNo <> Round(LineNo, 1)) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, DocumentErr, 'lineNo', Format(LineNo, 0, 9), 'positive integer; documentNo max 20 characters', '');
                exit(false);
            end;
            PermissionRef.Open(SourceTableNo(TypeName));
            if not PermissionRef.ReadPermission() or (NeedWrite and not PermissionRef.WritePermission()) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, 'documentType', DocumentType, '', '');
                exit(false);
            end;
            case TypeName of
                'SalesLine': begin
                    SalesLine.SetLoadFields(SystemId);
                    SalesLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := SalesLine.Get(Subtype, DocumentNo, LineNo);
                    IdText := Format(SalesLine.SystemId, 0, 4);
                end;
                'PurchaseLine': begin
                    PurchaseLine.SetLoadFields(SystemId);
                    PurchaseLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := PurchaseLine.Get(Subtype, DocumentNo, LineNo);
                    IdText := Format(PurchaseLine.SystemId, 0, 4);
                end;
                'TransferLine': begin
                    TransferLine.SetLoadFields(SystemId);
                    TransferLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := TransferLine.Get(DocumentNo, LineNo);
                    IdText := Format(TransferLine.SystemId, 0, 4);
                end;
            end;
            if not Found then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, DocumentErr, 'documentNo', DocumentNo, '', '');
                exit(false);
            end;
        end;
        Source.Add('systemId', IdText);
        if Request.Get('transferDirection', Token) then
            Source.Add('transferDirection', Token);
        SourceRequest.Add('source', Source);
        if not Resolve(Argument, SourceRequest, 'source', NeedWrite, SourceRef, Specification, Direction) then
            exit(false);
        if (TypeName <> 'TransferLine') and (Specification."Source Subtype" <> Subtype) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentErr, 'documentType', DocumentType, '', '');
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Returns stable sales, purchase and transfer document names for wire responses.</summary>
    procedure DocumentTypeName(TableNo: Integer; Subtype: Integer): Text
    var
        Family: Text;
    begin
        case TableNo of
            Database::"Sales Line": Family := 'Sales.';
            Database::"Purchase Line": Family := 'Purchase.';
            Database::"Transfer Line": exit('Transfer.Order');
            else exit('');
        end;
        case Subtype of
            0: exit(Family + 'Quote');
            1: exit(Family + 'Order');
            2: exit(Family + 'Invoice');
            3: exit(Family + 'CreditMemo');
            4: exit(Family + 'BlanketOrder');
            5: exit(Family + 'ReturnOrder');
        end;
        exit('');
    end;

    /// <summary>Returns a stable wire name rather than a localized table caption or numeric table ID.</summary>
    procedure SourceTypeName(TableNo: Integer): Text
    begin
        case TableNo of
            Database::"Sales Line":
                exit('SalesLine');
            Database::"Purchase Line":
                exit('PurchaseLine');
            Database::"Transfer Line":
                exit('TransferLine');
            Database::"Assembly Header":
                exit('AssemblyHeader');
            Database::"Assembly Line":
                exit('AssemblyLine');
            Database::"Service Line":
                exit('ServiceLine');
            Database::"Prod. Order Line":
                exit('ProdOrderLine');
            Database::"Prod. Order Component":
                exit('ProdOrderComponent');
            Database::"Item Journal Line":
                exit('ItemJournalLine');
            Database::"Requisition Line":
                exit('RequisitionLine');
            Database::"Planning Component":
                exit('PlanningComponent');
            Database::"Job Journal Line":
                exit('JobJournalLine');
            Database::"Job Planning Line":
                exit('JobPlanningLine');
            Database::"Invt. Document Line":
                exit('InventoryDocumentLine');
            Database::"Item Ledger Entry":
                exit('ItemLedgerEntry');
        end;
        exit('Unknown');
    end;

    /// <summary>Reads a JSON string without coercing objects, arrays, null, numbers or booleans.</summary>
    procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        InvalidTextErr: Label 'Specify %1 as text.', Comment = '%1 = request property, is-IS=Tilgreindu %1 sem texta.';
    begin
        Clear(Value);
        if not Request.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidTextErr, KeyName), KeyName, '', 'string', '');
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidTextErr, KeyName), KeyName, Serialized, 'string', '');
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidTextErr, KeyName), KeyName, '', 'nonempty string', '');
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Maps only W1 reservation sources; arbitrary tables are never opened.</summary>
    procedure SourceTableNo(TypeName: Text): Integer
    begin
        case TypeName of
            'SalesLine':
                exit(Database::"Sales Line");
            'PurchaseLine':
                exit(Database::"Purchase Line");
            'TransferLine':
                exit(Database::"Transfer Line");
        end;
        exit(0);
    end;

    /// <summary>Uses each native source adapter, preserving quantities, UOM, source keys and posting progress.</summary>
    procedure InitializeSpecification(SourceRef: RecordRef; Direction: Enum "Transfer Direction"; var Specification: Record "Tracking Specification")
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
        PurchaseLineReserve: Codeunit "Purch. Line-Reserve";
        TransferLineReserve: Codeunit "Transfer Line-Reserve";
        AvailabilityDate: Date;
    begin
        Clear(Specification);
        case SourceRef.Number of
            Database::"Sales Line":
                begin
                    SourceRef.SetTable(SalesLine);
                    // Full-record by native contract: SalesLineReserve.InitFromSalesLine.
                    SalesLineReserve.InitFromSalesLine(Specification, SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    SourceRef.SetTable(PurchaseLine);
                    // Full-record by native contract: PurchaseLineReserve.InitFromPurchLine.
                    PurchaseLineReserve.InitFromPurchLine(Specification, PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    SourceRef.SetTable(TransferLine);
                    // Full-record by native contract: TransferLineReserve.InitFromTransLine.
                    TransferLineReserve.InitFromTransLine(Specification, TransferLine, AvailabilityDate, Direction);
                end;
        end;
        Specification.TestField("Source Type");
        Specification.TestField("Item No.");
    end;
}
