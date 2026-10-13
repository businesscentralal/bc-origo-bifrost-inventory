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

/// <summary>Resolves real W1 reservation sources and initializes their native tracking specification.</summary>
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
        if not SourceRef.GetBySystemId(SourceId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingSourceErr, KeyName + '.systemId', IdText, '', '');
            exit(false);
        end;
        InitializeSpecification(SourceRef, Direction, Specification);
        exit(true);
    end;

    /// <summary>Checks the source permissions used by discovery without granting ledger write access.</summary>
    procedure HasTrackingWritePermission(): Boolean
    var
        SourceRef: RecordRef;
        TypeName: Text;
        Types: List of [Text];
    begin
        Types.Add('SalesLine');
        Types.Add('PurchaseLine');
        Types.Add('TransferLine');
        Types.Add('AssemblyHeader');
        Types.Add('AssemblyLine');
        Types.Add('ItemJournalLine');
        foreach TypeName in Types do begin
            SourceRef.Open(SourceTableNo(TypeName));
            if SourceRef.ReadPermission() and SourceRef.WritePermission() then
                exit(true);
            SourceRef.Close();
        end;
        exit(false);
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
            'AssemblyHeader':
                exit(Database::"Assembly Header");
            'AssemblyLine':
                exit(Database::"Assembly Line");
            'ServiceLine':
                exit(Database::"Service Line");
            'ProdOrderLine':
                exit(Database::"Prod. Order Line");
            'ProdOrderComponent':
                exit(Database::"Prod. Order Component");
            'ItemJournalLine':
                exit(Database::"Item Journal Line");
            'RequisitionLine':
                exit(Database::"Requisition Line");
            'PlanningComponent':
                exit(Database::"Planning Component");
            'JobJournalLine':
                exit(Database::"Job Journal Line");
            'JobPlanningLine':
                exit(Database::"Job Planning Line");
            'InventoryDocumentLine':
                exit(Database::"Invt. Document Line");
            'ItemLedgerEntry':
                exit(Database::"Item Ledger Entry");
        end;
        exit(0);
    end;

    /// <summary>Uses each native source adapter, preserving quantities, UOM, source keys and posting progress.</summary>
    procedure InitializeSpecification(SourceRef: RecordRef; Direction: Enum "Transfer Direction"; var Specification: Record "Tracking Specification")
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        ServiceLine: Record "Service Line";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        ItemJournalLine: Record "Item Journal Line";
        RequisitionLine: Record "Requisition Line";
        PlanningComponent: Record "Planning Component";
        JobJournalLine: Record "Job Journal Line";
        JobPlanningLine: Record "Job Planning Line";
        InventoryDocumentLine: Record "Invt. Document Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
        PurchaseLineReserve: Codeunit "Purch. Line-Reserve";
        TransferLineReserve: Codeunit "Transfer Line-Reserve";
        AssemblyHeaderReserve: Codeunit "Assembly Header-Reserve";
        AssemblyLineReserve: Codeunit "Assembly Line-Reserve";
        ServiceLineReserve: Codeunit "Service Line-Reserve";
        ProdOrderLineReserve: Codeunit "Prod. Order Line-Reserve";
        ProdOrderComponentReserve: Codeunit "Prod. Order Comp.-Reserve";
        ItemJournalLineReserve: Codeunit "Item Jnl. Line-Reserve";
        RequisitionLineReserve: Codeunit "Req. Line-Reserve";
        PlanningComponentReserve: Codeunit "Plng. Component-Reserve";
        JobJournalLineReserve: Codeunit "Job Jnl. Line-Reserve";
        JobPlanningLineReserve: Codeunit "Job Planning Line-Reserve";
        InventoryDocumentLineReserve: Codeunit "Invt. Doc. Line-Reserve";
        AvailabilityDate: Date;
    begin
        Clear(Specification);
        case SourceRef.Number of
            Database::"Sales Line":
                begin
                    SourceRef.SetTable(SalesLine);
                    SalesLineReserve.InitFromSalesLine(Specification, SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    SourceRef.SetTable(PurchaseLine);
                    PurchaseLineReserve.InitFromPurchLine(Specification, PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    SourceRef.SetTable(TransferLine);
                    TransferLineReserve.InitFromTransLine(Specification, TransferLine, AvailabilityDate, Direction);
                end;
            Database::"Assembly Header":
                begin
                    SourceRef.SetTable(AssemblyHeader);
                    AssemblyHeaderReserve.InitFromAsmHeader(Specification, AssemblyHeader);
                end;
            Database::"Assembly Line":
                begin
                    SourceRef.SetTable(AssemblyLine);
                    AssemblyLineReserve.InitFromAsmLine(Specification, AssemblyLine);
                end;
            Database::"Service Line":
                begin
                    SourceRef.SetTable(ServiceLine);
                    ServiceLineReserve.InitFromServLine(Specification, ServiceLine, false);
                end;
            Database::"Prod. Order Line":
                begin
                    SourceRef.SetTable(ProdOrderLine);
                    ProdOrderLineReserve.InitFromProdOrderLine(Specification, ProdOrderLine);
                end;
            Database::"Prod. Order Component":
                begin
                    SourceRef.SetTable(ProdOrderComponent);
                    ProdOrderComponentReserve.InitFromProdOrderComp(Specification, ProdOrderComponent);
                end;
            Database::"Item Journal Line":
                begin
                    SourceRef.SetTable(ItemJournalLine);
                    ItemJournalLineReserve.InitFromItemJnlLine(Specification, ItemJournalLine);
                end;
            Database::"Requisition Line":
                begin
                    SourceRef.SetTable(RequisitionLine);
                    RequisitionLineReserve.InitFromReqLine(Specification, RequisitionLine);
                end;
            Database::"Planning Component":
                begin
                    SourceRef.SetTable(PlanningComponent);
                    PlanningComponentReserve.InitFromProdPlanningComp(Specification, PlanningComponent);
                end;
            Database::"Job Journal Line":
                begin
                    SourceRef.SetTable(JobJournalLine);
                    JobJournalLineReserve.InitFromJobJnlLine(Specification, JobJournalLine);
                end;
            Database::"Job Planning Line":
                begin
                    SourceRef.SetTable(JobPlanningLine);
                    JobPlanningLineReserve.InitFromJobPlanningLine(Specification, JobPlanningLine);
                end;
            Database::"Invt. Document Line":
                begin
                    SourceRef.SetTable(InventoryDocumentLine);
                    InventoryDocumentLineReserve.InitFromInvtDocLine(Specification, InventoryDocumentLine);
                end;
            Database::"Item Ledger Entry":
                begin
                    SourceRef.SetTable(ItemLedgerEntry);
                    Specification.InitTrackingSpecification(Database::"Item Ledger Entry", 0, '', '', 0, ItemLedgerEntry."Entry No.", ItemLedgerEntry."Variant Code", ItemLedgerEntry."Location Code", ItemLedgerEntry."Qty. per Unit of Measure");
                    Specification."Item No." := ItemLedgerEntry."Item No.";
                    Specification.Description := ItemLedgerEntry.Description;
                    Specification."Quantity (Base)" := ItemLedgerEntry."Remaining Quantity";
                    Specification."Lot No." := ItemLedgerEntry."Lot No.";
                    Specification."Serial No." := ItemLedgerEntry."Serial No.";
                    Specification."Package No." := ItemLedgerEntry."Package No.";
                    Specification."Expiration Date" := ItemLedgerEntry."Expiration Date";
                end;
        end;
        Specification.TestField("Source Type");
        Specification.TestField("Item No.");
    end;
}
