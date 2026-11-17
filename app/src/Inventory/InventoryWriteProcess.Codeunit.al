namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
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
        TempReserveTracking: Record "Reservation Entry" temporary;
        JournalType: Enum "Item Journal Template Type";
        Operation: Text;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceNo: Code[20];
        SourceLineNo: Integer;
        SourceBatchName: Code[10];
        SourceProdOrderLine: Integer;
        SupplyEntryNo: Integer;
        ReserveQuantity: Decimal;
        ReserveQuantityBase: Decimal;
        AvailabilityDate: Date;
        ReserveDescription: Text[100];
        CostItemFilter: Text;
        CostDateFilter: Text;
        CostJournalTemplate: Code[10];
        CostJournalBatch: Code[10];
        PostedAssemblyNo: Code[20];
        RecreateAssemblyOrder: Boolean;
        CancelEntryNos: List of [Integer];
        ApplicationEntryNo: Integer;
        ApplyToEntryNo: Integer;
        ApplicationLedgerEntryNo: Integer;
        ApplicationQuantity: Decimal;
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
                UndoAssembly(Rec);
            'ItemApplicationUnapply':
                UnapplyItemEntry();
            'ItemApplicationReapply':
                ReapplyItemEntry();
            'CostToGLPost':
                PostCostToGL(Rec);
            else
                Error(UnknownOperationErr);
        end;
    end;

    /// <summary>Selects the write: Post (or blank), Calculate, RecordCount, RevaluationPost, CostUpdate, PriceUpdate, ReservationCreate, ReservationCancel, ItemApplicationUnapply or ItemApplicationReapply.</summary>
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
    /// <param name="NewSourceType">The native reservation source table number.</param>
    /// <param name="NewSourceSubtype">Document type, production status, journal entry type, or transfer direction 0 outbound / 1 inbound.</param>
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

    /// <summary>Sets the additional native source key parts for journal and production reservations.</summary>
    /// <param name="BatchName">Item journal batch name, otherwise blank.</param>
    /// <param name="ProdOrderLine">Production order line number for a production line or component, otherwise zero.</param>
    procedure SetReservationSourceDetails(BatchName: Code[10]; ProdOrderLine: Integer)
    begin
        SourceBatchName := BatchName;
        SourceProdOrderLine := ProdOrderLine;
    end;

    /// <summary>Restricts ReservationCreate to tracking values and optionally one inventory supply entry.</summary>
    /// <param name="ItemLedgerEntryNo">Supply entry number, or zero for general matching supply.</param>
    /// <param name="LotNo">Lot number filter, or blank.</param>
    /// <param name="SerialNo">Serial number filter, or blank.</param>
    /// <param name="PackageNo">Package number filter, or blank.</param>
    procedure SetReservationSupply(ItemLedgerEntryNo: Integer; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50])
    begin
        SupplyEntryNo := ItemLedgerEntryNo;
        TempReserveTracking."Lot No." := LotNo;
        TempReserveTracking."Serial No." := SerialNo;
        TempReserveTracking."Package No." := PackageNo;
    end;

    /// <summary>Sets the reservation entry pair for the ReservationCancel operation (select it with SetOperation).</summary>
    /// <param name="EntryNo">The reservation entry number (both sides of the pair share it).</param>
    procedure SetCancelReservation(EntryNo: Integer)
    begin
        Clear(CancelEntryNos);
        CancelEntryNos.Add(EntryNo);
    end;

    /// <summary>Sets several reservation entry pairs for the ReservationCancel operation; all are cancelled in one transaction.</summary>
    /// <param name="EntryNos">The reservation entry numbers (both sides of each pair share the number).</param>
    procedure SetCancelReservations(EntryNos: List of [Integer])
    var
        EntryNo: Integer;
    begin
        Clear(CancelEntryNos);
        foreach EntryNo in EntryNos do
            CancelEntryNos.Add(EntryNo);
    end;

    /// <summary>Returns whether the last ReservationCreate reserved the full requested quantity.</summary>
    /// <returns>True when the full quantity was reserved.</returns>
    procedure GetFullAutoReservation(): Boolean
    begin
        exit(FullAutoReservation);
    end;

    /// <summary>Sets the pending-entry item and posting date selection and the optional mandatory G/L journal batch.</summary>
    procedure SetCostPostingSelection(ItemFilter: Text; DateFilter: Text; JournalTemplate: Code[10]; JournalBatch: Code[10])
    begin
        CostItemFilter := ItemFilter;
        CostDateFilter := DateFilter;
        CostJournalTemplate := JournalTemplate;
        CostJournalBatch := JournalBatch;
    end;

    /// <summary>Selects native application entries for the existing atomic write boundary.</summary>
    /// <param name="EntryNo">Application entry for Unapply, or item ledger entry for Reapply.</param>
    /// <param name="ApplyWith">Item ledger entry to apply with; zero for Unapply.</param>
    procedure SetApplicationEntries(EntryNo: Integer; ApplyWith: Integer)
    begin
        ApplicationEntryNo := EntryNo;
        ApplyToEntryNo := ApplyWith;
        ApplicationLedgerEntryNo := 0;
        ApplicationQuantity := 0;
    end;

    /// <summary>Selects all real applications linked to one ledger entry for atomic unapplication.</summary>
    procedure SetApplicationLedger(EntryNo: Integer)
    begin
        ApplicationLedgerEntryNo := EntryNo;
    end;

    /// <summary>Limits the native reapplication to an exact positive quantity in base units.</summary>
    procedure SetApplicationQuantity(Quantity: Decimal)
    begin
        ApplicationQuantity := Quantity;
    end;

    local procedure UnapplyItemEntry()
    var
        ApplicationEntry: Record "Item Application Entry";
        NativePost: Codeunit "Item Jnl.-Post Line";
    begin
        ApplicationEntry.LockTable();
        if ApplicationLedgerEntryNo = 0 then begin
            ApplicationEntry.Get(ApplicationEntryNo);
            NativePost.UnApply(ApplicationEntry);
            MarkApplicationForAdjustment(ApplicationEntry);
            exit;
        end;
        ApplicationEntry.FilterGroup(-1);
        ApplicationEntry.SetRange("Inbound Item Entry No.", ApplicationLedgerEntryNo);
        ApplicationEntry.SetRange("Outbound Item Entry No.", ApplicationLedgerEntryNo);
        ApplicationEntry.FilterGroup(0);
        ApplicationEntry.SetFilter("Outbound Item Entry No.", '<>0');
        ApplicationEntry.FindFirst();
        repeat
            NativePost.UnApply(ApplicationEntry);
            MarkApplicationForAdjustment(ApplicationEntry);
        until not ApplicationEntry.FindFirst();
    end;

    local procedure ReapplyItemEntry()
    var
        LedgerEntry: Record "Item Ledger Entry";
        InboundEntry: Record "Item Ledger Entry";
        NativePost: Codeunit "Item Jnl.-Post Line";
        QuantityLimit: Codeunit "Item Appl. Quantity ori";
        BeforeOutbound: Decimal;
        BeforeInbound: Decimal;
        InvalidPairErr: Label 'Select a negative outbound and positive inbound entry of the same item, variant and location.', Comment = 'is-IS=Veldu neikvæða útleiðandi og jákvæða innleiðandi færslu fyrir sömu vöru, afbrigði og birgðageymslu.';
        QuantityErr: Label 'The requested base quantity must be available on both entries and must be applied exactly.', Comment = 'is-IS=Umbeðið magn í grunneiningum verður að vera tiltækt á báðum færslum og jafnað nákvæmlega.';
    begin
        LedgerEntry.LockTable();
        LedgerEntry.Get(ApplicationEntryNo);
        if ApplicationQuantity = 0 then begin
            NativePost.ReApply(LedgerEntry, ApplyToEntryNo);
            exit;
        end;
        InboundEntry.Get(ApplyToEntryNo);
        if LedgerEntry.Positive or (LedgerEntry.Quantity >= 0) or not InboundEntry.Positive or (InboundEntry.Quantity <= 0) or
           (LedgerEntry."Item No." <> InboundEntry."Item No.") or (LedgerEntry."Variant Code" <> InboundEntry."Variant Code") or
           (LedgerEntry."Location Code" <> InboundEntry."Location Code")
        then
            Error(InvalidPairErr);
        LedgerEntry.CalcFields("Reserved Quantity");
        InboundEntry.CalcFields("Reserved Quantity");
        if (ApplicationQuantity > -(LedgerEntry."Remaining Quantity" - LedgerEntry."Reserved Quantity")) or
           (ApplicationQuantity > InboundEntry."Remaining Quantity" - InboundEntry."Reserved Quantity")
        then
            Error(QuantityErr);
        BeforeOutbound := LedgerEntry."Remaining Quantity";
        BeforeInbound := InboundEntry."Remaining Quantity";
        QuantityLimit.SetSelection(ApplicationEntryNo, ApplyToEntryNo, ApplicationQuantity);
        BindSubscription(QuantityLimit);
        NativePost.ReApply(LedgerEntry, ApplyToEntryNo);
        UnbindSubscription(QuantityLimit);
        LedgerEntry.Get(ApplicationEntryNo);
        InboundEntry.Get(ApplyToEntryNo);
        if (LedgerEntry."Remaining Quantity" - BeforeOutbound <> ApplicationQuantity) or
           (BeforeInbound - InboundEntry."Remaining Quantity" <> ApplicationQuantity)
        then
            Error(QuantityErr);
    end;

    local procedure MarkApplicationForAdjustment(ApplicationEntry: Record "Item Application Entry")
    begin
        MarkEntryForAdjustment(ApplicationEntry."Inbound Item Entry No.");
        MarkEntryForAdjustment(ApplicationEntry."Outbound Item Entry No.");
    end;

    local procedure MarkEntryForAdjustment(EntryNo: Integer)
    var
        Ledger: Record "Item Ledger Entry";
        Item: Record Item;
    begin
        Ledger.Get(EntryNo);
        Ledger."Applied Entry to Adjust" := true;
        Ledger.Modify();
        Item.Get(Ledger."Item No.");
        if Item."Cost is Adjusted" then begin
            Item."Cost is Adjusted" := false;
            Item.Modify();
        end;
    end;

    local procedure PostCostToGL(var Argument: Record "Message Argument ori")
    var
        Pending: Record "Post Value Entry to G/L";
        PostInventoryCost: Report "Post Inventory Cost to G/L";
        Response: JsonObject;
        BeforeCount: Integer;
        RemainingCount: Integer;
    begin
        if CostItemFilter <> '' then
            Pending.SetFilter("Item No.", CostItemFilter);
        if CostDateFilter <> '' then
            Pending.SetFilter("Posting Date", CostDateFilter);
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
        Response.Add('postingDateFilter', CostDateFilter);
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

    /// <summary>Controls native recreation when the original assembly order no longer exists.</summary>
    /// <param name="RecreateOrder">True to recreate the original order after undo.</param>
    procedure SetRecreateAssemblyOrder(RecreateOrder: Boolean)
    begin
        RecreateAssemblyOrder := RecreateOrder;
    end;

    local procedure UndoAssembly(var Argument: Record "Message Argument ori")
    var
        PostedAssembly: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        Request: JsonObject;
        Token: JsonToken;
        RecreateOrder: Boolean;
    begin
        RecreateOrder := RecreateAssemblyOrder;
        Request := Argument.GetRequestJson();
        if Request.Get('recreateOrder', Token) then
            RecreateOrder := Token.AsValue().AsBoolean();
        PostedAssembly.Get(PostedAssemblyNo);
        AssemblyPost.SetSuppressCommit(true);
        AssemblyPost.Undo(PostedAssembly, RecreateOrder);
    end;

    local procedure Reserve()
    var
        DemandEntry: Record "Reservation Entry";
        SalesLine: Record "Sales Line";
        ServiceLine: Record "Service Line";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        ItemJournalLine: Record "Item Journal Line";
        AssemblyHeader: Record "Assembly Header";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        AssemblyLine: Record "Assembly Line";
        ReservationManagement: Codeunit "Reservation Management";
        JournalContext: Codeunit "Reserv. Supply Filter ori";
    begin
        case SourceType of
            Database::"Service Line":
                begin
                    ServiceLine.Get(Enum::"Service Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    ServiceLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(ServiceLine);
                end;
            Database::"Prod. Order Line":
                begin
                    ProdOrderLine.Get(Enum::"Production Order Status".FromInteger(SourceSubtype), SourceNo, SourceProdOrderLine);
                    ProdOrderLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(ProdOrderLine);
                end;
            Database::"Prod. Order Component":
                begin
                    ProdOrderComponent.Get(Enum::"Production Order Status".FromInteger(SourceSubtype), SourceNo, SourceProdOrderLine, SourceLineNo);
                    ProdOrderComponent.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(ProdOrderComponent);
                end;
            Database::"Item Journal Line":
                begin
                    ItemJournalLine.Get(CopyStr(SourceNo, 1, 10), SourceBatchName, SourceLineNo);
                    ItemJournalLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(ItemJournalLine);
                end;
            Database::"Assembly Header":
                begin
                    AssemblyHeader.Get(Enum::"Assembly Document Type".FromInteger(SourceSubtype), SourceNo);
                    AssemblyHeader.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(AssemblyHeader);
                end;
            Database::"Sales Line":
                begin
                    SalesLine.Get(Enum::"Sales Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    SalesLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    PurchaseLine.Get(Enum::"Purchase Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    PurchaseLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    TransferLine.Get(SourceNo, SourceLineNo);
                    TransferLine.SetReservationEntry(DemandEntry, Enum::"Transfer Direction".FromInteger(SourceSubtype));
                    ReservationManagement.SetReservSource(TransferLine, Enum::"Transfer Direction".FromInteger(SourceSubtype));
                end;
            Database::"Assembly Line":
                begin
                    AssemblyLine.Get(Enum::"Assembly Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo);
                    AssemblyLine.SetReservationEntry(DemandEntry);
                    ReservationManagement.SetReservSource(AssemblyLine);
                end;
        end;
        ReservationManagement.SetTrackingFromReservEntry(TempReserveTracking);
        if SupplyEntryNo <> 0 then
            ReserveSupplyEntry(ReservationManagement, DemandEntry)
        else begin
            // Item journals have native CreateReservation support but do not supply AutoReserve's remaining-quantity event.
            if SourceType = Database::"Item Journal Line" then
                BindSubscription(JournalContext);
            ReservationManagement.AutoReserve(FullAutoReservation, ReserveDescription, AvailabilityDate, ReserveQuantity, ReserveQuantityBase);
            if SourceType = Database::"Item Journal Line" then
                UnbindSubscription(JournalContext);
        end;
    end;

    local procedure ReserveSupplyEntry(var ReservationManagement: Codeunit "Reservation Management"; DemandEntry: Record "Reservation Entry")
    var
        LedgerEntry: Record "Item Ledger Entry";
        SupplyFilter: Codeunit "Reserv. Supply Filter ori";
        RemainingQuantity: Decimal;
        RemainingQuantityBase: Decimal;
        SupplyUnavailableErr: Label 'The selected item ledger entry does not have enough matching, unreserved inventory for this source line.', Comment = 'is-IS=Valin vörufærsla hefur ekki nægar samsvarandi ófráteknar birgðir fyrir þessa upprunalínu.';
    begin
        LedgerEntry.Get(SupplyEntryNo);
        if not ReservationManagement.IsPositive() or not LedgerEntry.Positive or not LedgerEntry.Open or
           (LedgerEntry."Item No." <> DemandEntry."Item No.") or
           (LedgerEntry."Variant Code" <> DemandEntry."Variant Code") or
           (LedgerEntry."Location Code" <> DemandEntry."Location Code") or
           ((TempReserveTracking."Lot No." <> '') and (LedgerEntry."Lot No." <> TempReserveTracking."Lot No.")) or
           ((TempReserveTracking."Serial No." <> '') and (LedgerEntry."Serial No." <> TempReserveTracking."Serial No.")) or
           ((TempReserveTracking."Package No." <> '') and (LedgerEntry."Package No." <> TempReserveTracking."Package No."))
        then
            Error(SupplyUnavailableErr);
        TempReserveTracking.CopyTrackingFromItemLedgEntry(LedgerEntry);
        ReservationManagement.SetTrackingFromReservEntry(TempReserveTracking);
        RemainingQuantity := ReserveQuantity;
        RemainingQuantityBase := ReserveQuantityBase;
        SupplyFilter.SetSupplyEntry(SupplyEntryNo);
        BindSubscription(SupplyFilter);
        // Retain the native warehouse availability, tracking, source-quantity and reservation checks.
        ReservationManagement.AutoReserveOneLine(Enum::"Reservation Summary Type"::"Item Ledger Entry".AsInteger(),
            RemainingQuantity, RemainingQuantityBase, ReserveDescription, AvailabilityDate);
        UnbindSubscription(SupplyFilter);
        if RemainingQuantityBase <> 0 then
            Error(SupplyUnavailableErr);
        FullAutoReservation := true;
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
        CancelEntryNo: Integer;
        InconsistentPairErr: Label 'Reservation %1 no longer contains a consistent reservation pair.', Comment = '%1 = entry number; is-IS=Frátekning %1 inniheldur ekki lengur samræmt frátekningarpar.';
    begin
        ReservationEntry.LockTable();
        foreach CancelEntryNo in CancelEntryNos do begin
            if not HasConsistentReservationPair(CancelEntryNo, ReservationEntry) then
                Error(InconsistentPairErr, CancelEntryNo);
            ReservationEngineMgt.CancelReservation(ReservationEntry);
        end;
    end;
}
