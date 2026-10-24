namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Runs one native Inventory write inside its own Codeunit.Run transaction, so a native validation
/// failure rolls back every change of that write and the dispatcher can answer with the error.
/// Select the write with SetOperation (and the related setter) before Run.
/// </summary>
codeunit 10076842 "Inventory Write Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        JournalType: Enum "Item Journal Template Type";
        Operation: Text;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceNo: Code[20];
        SourceLineNo: Integer;
        ReserveQuantity: Decimal;
        ReserveQuantityBase: Decimal;
        AvailabilityDate: Date;
        ReserveDescription: Text[100];
        CostItemFilter: Text;
        CostDocumentFilter: Text;
        CostJournalTemplate: Code[10];
        CostJournalBatch: Code[10];
        PostedAssemblyNo: Code[20];
        CancelEntryNo: Integer;
        FullAutoReservation: Boolean;
        UnknownOperationErr: Label 'Unknown inventory write operation.', Comment = 'is-IS=Óþekkt birgðaskrifaðgerð.';

    trigger OnRun()
    var
        Journal: Codeunit "Inventory Native Journal ori";
        CardWrite: Codeunit "Inventory Card Write ori";
    begin
        case Operation of
            '', 'Post':
                Journal.Post(Rec, JournalType);
            'Calculate':
                Journal.Calculate(Rec);
            'RecordCount':
                Journal.RecordCount(Rec);
            'RevaluationPost':
                Journal.PostRevaluation(Rec);
            'CostUpdate':
                CardWrite.UpdateCost(Rec);
            'PriceUpdate':
                CardWrite.UpdatePrice(Rec);
            'ReservationCreate':
                Reserve();
            'ReservationCancel':
                CancelReservation();
            'AssemblyUndo':
                UndoAssembly();
            'CostToGLPost':
                PostCostToGL(Rec);
            else
                Error(UnknownOperationErr);
        end;
    end;

    /// <summary>Selects the write: Post (or blank), Calculate, RecordCount, RevaluationPost, CostUpdate, PriceUpdate, ReservationCreate or ReservationCancel.</summary>
    /// <param name="NewOperation">The operation name.</param>
    procedure SetOperation(NewOperation: Text)
    begin
        Operation := NewOperation;
    end;

    /// <summary>Selects the dedicated native journal family for the journal Post operation.</summary>
    /// <param name="NewJournalType">The item journal template type.</param>
    procedure SetJournalType(NewJournalType: Enum "Item Journal Template Type")
    begin
        JournalType := NewJournalType;
    end;

    /// <summary>Sets the source line and quantity for the ReservationCreate operation (select it with SetOperation).</summary>
    /// <param name="NewSourceType">Source table number: Sales Line, Purchase Line, Transfer Line or Assembly Line.</param>
    /// <param name="NewSourceSubtype">Document type, or transfer direction 0 outbound / 1 inbound.</param>
    /// <param name="NewSourceNo">Source document number.</param>
    /// <param name="NewSourceLineNo">Source line number.</param>
    /// <param name="NewQuantity">Quantity to reserve in the line unit of measure.</param>
    /// <param name="NewQuantityBase">Quantity to reserve in the base unit of measure.</param>
    /// <param name="NewAvailabilityDate">Date the supply must be available.</param>
    /// <param name="NewDescription">Description written on the reservation entries.</param>
    procedure SetReservation(NewSourceType: Integer; NewSourceSubtype: Integer; NewSourceNo: Code[20]; NewSourceLineNo: Integer; NewQuantity: Decimal; NewQuantityBase: Decimal; NewAvailabilityDate: Date; NewDescription: Text[100])
    begin
        SourceType := NewSourceType;
        SourceSubtype := NewSourceSubtype;
        SourceNo := NewSourceNo;
        SourceLineNo := NewSourceLineNo;
        ReserveQuantity := NewQuantity;
        ReserveQuantityBase := NewQuantityBase;
        AvailabilityDate := NewAvailabilityDate;
        ReserveDescription := NewDescription;
    end;

    /// <summary>Sets the reservation entry pair for the ReservationCancel operation (select it with SetOperation).</summary>
    /// <param name="EntryNo">The reservation entry number (both sides of the pair share it).</param>
    procedure SetCancelReservation(EntryNo: Integer)
    begin
        CancelEntryNo := EntryNo;
    end;

    /// <summary>Returns whether the last ReservationCreate reserved the full requested quantity.</summary>
    /// <returns>True when the full quantity was reserved.</returns>
    procedure GetFullAutoReservation(): Boolean
    begin
        exit(FullAutoReservation);
    end;

    /// <summary>Sets native cost posting selection and the optional mandatory G/L journal batch.</summary>
    procedure SetCostPostingSelection(ItemFilter: Text; DocumentFilter: Text; JournalTemplate: Code[10]; JournalBatch: Code[10])
    begin
        CostItemFilter := ItemFilter;
        CostDocumentFilter := DocumentFilter;
        CostJournalTemplate := JournalTemplate;
        CostJournalBatch := JournalBatch;
    end;

    local procedure PostCostToGL(var Argument: Record "Message Argument ori")
    var
        Pending: Record "Post Value Entry to G/L";
        ValueEntry: Record "Value Entry";
        PostInventoryCost: Report "Post Inventory Cost to G/L";
        EntryFilter: Text;
        Response: JsonObject;
        BeforeCount: Integer;
        RemainingCount: Integer;
    begin
        if CostItemFilter <> '' then
            Pending.SetFilter("Item No.", CostItemFilter);
        if CostDocumentFilter <> '' then begin
            ValueEntry.SetFilter("Document No.", CostDocumentFilter);
            if Pending.FindSet() then
                repeat
                    ValueEntry.SetRange("Entry No.", Pending."Value Entry No.");
                    if not ValueEntry.IsEmpty() then begin
                        if EntryFilter <> '' then
                            EntryFilter += '|';
                        EntryFilter += Format(Pending."Value Entry No.", 0, 9);
                    end;
                until Pending.Next() = 0;
            if EntryFilter = '' then
                Pending.SetRange("Value Entry No.", 0)
            else
                Pending.SetFilter("Value Entry No.", EntryFilter);
        end;
        BeforeCount := Pending.Count();
        // Native per-entry posting uses each value entry's document number, not a fabricated document number.
        PostInventoryCost.InitializeRequest(1, '', true);
        if (CostJournalTemplate <> '') or (CostJournalBatch <> '') then
            PostInventoryCost.SetGenJnlBatch(CostJournalTemplate, CostJournalBatch);
        PostInventoryCost.SetTableView(Pending);
        PostInventoryCost.UseRequestPage(false);
        PostInventoryCost.Run();
        RemainingCount := Pending.Count();
        Response.Add('status', 'Success');
        Response.Add('itemNoFilter', CostItemFilter);
        Response.Add('documentNoFilter', CostDocumentFilter);
        Response.Add('postedValueEntryCount', BeforeCount - RemainingCount);
        Response.Add('remainingValueEntryCount', RemainingCount);
        Response.Add('posted', BeforeCount > RemainingCount);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Selects the owned posted assembly for an atomic AssemblyUndo operation.</summary>
    /// <param name="DocumentNo">The posted assembly number.</param>
    procedure SetPostedAssemblyNo(DocumentNo: Code[20])
    begin
        PostedAssemblyNo := DocumentNo;
    end;

    local procedure UndoAssembly()
    var
        PostedAssembly: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
    begin
        PostedAssembly.Get(PostedAssemblyNo);
        AssemblyPost.SetSuppressCommit(true);
        AssemblyPost.Undo(PostedAssembly, false);
    end;

    local procedure Reserve()
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        AssemblyLine: Record "Assembly Line";
        ReservationManagement: Codeunit "Reservation Management";
    begin
        case SourceType of
            Database::"Sales Line":
                begin
                    SalesLine.Get(Enum::"Sales Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    ReservationManagement.SetReservSource(SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    PurchaseLine.Get(Enum::"Purchase Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    ReservationManagement.SetReservSource(PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    TransferLine.Get(SourceNo, SourceLineNo);
                    ReservationManagement.SetReservSource(TransferLine, Enum::"Transfer Direction".FromInteger(SourceSubtype));
                end;
            Database::"Assembly Line":
                begin
                    AssemblyLine.Get(Enum::"Assembly Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    ReservationManagement.SetReservSource(AssemblyLine);
                end;
        end;
        ReservationManagement.AutoReserve(FullAutoReservation, ReserveDescription, AvailabilityDate, ReserveQuantity, ReserveQuantityBase);
    end;

    /// <summary>Reads both sides and refuses incomplete or inconsistent native reservation pairs.</summary>
    procedure HasConsistentReservationPair(EntryNo: Integer; var DemandEntry: Record "Reservation Entry"): Boolean
    var
        SupplyEntry: Record "Reservation Entry";
    begin
        if not DemandEntry.Get(EntryNo, false) or not SupplyEntry.Get(EntryNo, true) then
            exit(false);
        exit((DemandEntry."Reservation Status" = DemandEntry."Reservation Status"::Reservation) and
            (SupplyEntry."Reservation Status" = SupplyEntry."Reservation Status"::Reservation) and
            (DemandEntry."Item No." = SupplyEntry."Item No.") and
            (DemandEntry."Variant Code" = SupplyEntry."Variant Code") and
            (DemandEntry."Location Code" = SupplyEntry."Location Code") and
            (DemandEntry."Quantity (Base)" < 0) and
            (SupplyEntry."Quantity (Base)" = -DemandEntry."Quantity (Base)"));
    end;

    local procedure CancelReservation()
    var
        ReservationEntry: Record "Reservation Entry";
        ReservationEngineMgt: Codeunit "Reservation Engine Mgt.";
        InconsistentPairErr: Label 'Reservation %1 no longer contains a consistent reservation pair.', Comment = '%1 = entry number; is-IS=Frátekning %1 inniheldur ekki lengur samræmt frátekningarpar.';
    begin
        ReservationEntry.LockTable();
        if not HasConsistentReservationPair(CancelEntryNo, ReservationEntry) then
            Error(InconsistentPairErr, CancelEntryNo);
        ReservationEngineMgt.CancelReservation(ReservationEntry);
    end;
}
