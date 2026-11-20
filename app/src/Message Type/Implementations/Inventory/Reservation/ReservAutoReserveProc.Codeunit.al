namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.Reservation.AutoReserve, run with Codeunit.Run so that a partial
/// reservation is rolled back. The caller has already checked the request shape.
/// </summary>
codeunit 10076896 "Reserv. AutoReserve Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        OrderTok: Label 'Order', Locked = true;

    trigger OnRun()
    var
        SalesLine: Record "Sales Line";
        ReservationManagement: Codeunit "Reservation Management";
        RequestJson: JsonObject;
        EntriesBefore: List of [Integer];
        FullAutoReservation: Boolean;
        QuantityToReserve: Decimal;
        QuantityToReserveBase: Decimal;
        ReservedBefore: Decimal;
        ReservedBeforeBase: Decimal;
    begin
        RequestJson := Rec.GetRequestJson();
        // Reservation Management reads most fields of the source line, so the whole record is loaded.
        if not FindSalesLine(RequestJson, SalesLine) then begin
            RespondNotFound(Rec, RequestJson);
            exit;
        end;
        SalesLine.CalcFields("Reserved Quantity", "Reserved Qty. (Base)");
        if not CheckReservable(Rec, SalesLine) then
            exit;
        CollectReservationEntryNos(SalesLine, EntriesBefore);
        if RemainingBase(SalesLine) <= 0 then begin
            RespondSuccess(Rec, SalesLine, 0, EntriesBefore);
            exit;
        end;

        QuantityToReserve := RemainingQuantity(SalesLine);
        QuantityToReserveBase := RemainingBase(SalesLine);
        if RequestJson.Contains('quantity') then
            if ReadDecimal(RequestJson, 'quantity') < QuantityToReserve then begin
                QuantityToReserve := ReadDecimal(RequestJson, 'quantity');
                QuantityToReserveBase := Round(QuantityToReserve * QtyPerUnitOfMeasure(SalesLine), 0.00001);
            end;

        ReservedBefore := SalesLine."Reserved Quantity";
        ReservedBeforeBase := SalesLine."Reserved Qty. (Base)";
        ReservationManagement.SetReservSource(SalesLine);
        ReservationManagement.AutoReserve(FullAutoReservation, '', SalesLine."Shipment Date", QuantityToReserve, QuantityToReserveBase);

        SalesLine.Find();
        SalesLine.CalcFields("Reserved Quantity", "Reserved Qty. (Base)");
        if (not FullAutoReservation) or (SalesLine."Reserved Qty. (Base)" - ReservedBeforeBase < QuantityToReserveBase) then
            RaisePartial(Rec, SalesLine."Reserved Quantity" - ReservedBefore, QuantityToReserve);
        RespondSuccess(Rec, SalesLine, SalesLine."Reserved Quantity" - ReservedBefore, EntriesBefore);
    end;

    local procedure RaisePartial(var Argument: Record "Message Argument ori"; Reserved: Decimal; Requested: Decimal)
    var
        PartialErr: Label 'Only %1 of %2 could be reserved. Nothing is written.', Comment = '%1 = quantity reserved, %2 = quantity requested, is-IS=Aðeins var hægt að taka %1 af %2 frá. Ekkert er skrifað.';
        PartialNextStepLbl: Label 'Read Inventory.Reservation.Get for what was reserved.', Comment = 'is-IS=Lestu Inventory.Reservation.Get til að sjá hvað er tekið frá.';
    begin
        // Raising rolls the partial reservation back; the implementation answers from the collected error.
        Argument.AddError("Bifrost Error Code ori"::LinesSkipped, StrSubstNo(PartialErr, Format(Reserved, 0, 9), Format(Requested, 0, 9)), 'quantity', Format(Reserved, 0, 9), Format(Requested, 0, 9), PartialNextStepLbl);
        Argument.RaiseCollectedErrors("Bifrost Error Code ori"::LinesSkipped, StrSubstNo(PartialErr, Format(Reserved, 0, 9), Format(Requested, 0, 9)));
    end;

    local procedure CheckReservable(var Argument: Record "Message Argument ori"; SalesLine: Record "Sales Line"): Boolean
    var
        NotOrderErr: Label 'Only sales order lines can be auto-reserved.', Comment = 'is-IS=Aðeins er hægt að taka sölupöntunarlínur sjálfvirkt frá.';
        NothingOutstandingErr: Label 'The line has no outstanding quantity.', Comment = 'is-IS=Línan hefur ekkert útistandandi magn.';
        ReservableExpectedLbl: Label 'a reservable item line on a sales order', Comment = 'is-IS=vörulína á sölupöntun sem má taka frá';
        PreconditionNextStepLbl: Label 'Change the item''s Reserve setting or reserve manually.', Comment = 'is-IS=Breyttu stillingunni Frátekning á vörunni eða taktu frá handvirkt.';
    begin
        if SalesLine."Document Type" <> SalesLine."Document Type"::Order then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NotOrderErr, 'documentType', '', OrderTok, PreconditionNextStepLbl);
            exit(false);
        end;
        if not CheckSalesLinePolicy(Argument, SalesLine) then
            exit(false);
        if SalesLine."Outstanding Qty. (Base)" <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingOutstandingErr, 'lineNo', Format(SalesLine."Line No.", 0, 9), ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Resolves a project planning line (project, task, line) to its reservation source values.</summary>
    /// <param name="Argument">The message argument that receives a typed refusal.</param>
    /// <param name="JobNo">The project number.</param>
    /// <param name="JobTaskNo">The project task number.</param>
    /// <param name="PlanningLineNo">The planning line number.</param>
    /// <param name="ForReserve">True to also check that the line can be reserved; false for a cancel lookup.</param>
    /// <param name="SourceSubtype">Receives the reservation source subtype (the planning line status).</param>
    /// <param name="ContractEntryNo">Receives the job contract entry number used as the reservation source reference.</param>
    /// <param name="ItemNo">Receives the item number.</param>
    /// <param name="LocationCode">Receives the location code.</param>
    /// <param name="AvailabilityDate">Receives the planning date.</param>
    /// <param name="QtyPerUOM">Receives the quantity per unit of measure.</param>
    /// <param name="Description">Receives the line description.</param>
    /// <returns>True when the line resolved; otherwise a typed refusal with a nextStep was set.</returns>
    procedure ResolveProjectPlanningLine(var Argument: Record "Message Argument ori"; JobNo: Code[20]; JobTaskNo: Code[20]; PlanningLineNo: Integer; ForReserve: Boolean; var SourceSubtype: Integer; var ContractEntryNo: Integer; var ItemNo: Code[20]; var LocationCode: Code[10]; var AvailabilityDate: Date; var QtyPerUOM: Decimal; var Description: Text[100]): Boolean
    var
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        Item: Record Item;
        NotFoundErr: Label 'Project planning line %1 %2 %3 was not found.', Comment = '%1 = project no.; %2 = task no.; %3 = line no.; is-IS=Verkáætlunarlína %1 %2 %3 fannst ekki.';
        NotFoundNextStepLbl: Label 'Check sourceNo (project), sourceTaskNo and sourceLineNo, and read the project planning lines first.', Comment = 'is-IS=Athugaðu sourceNo (verkefni), sourceTaskNo og sourceLineNo og lestu verkáætlunarlínurnar fyrst.';
        NotItemErr: Label 'Project planning line %1 %2 %3 is not an item line. Only item lines can be reserved.', Comment = '%1 = project no.; %2 = task no.; %3 = line no.; is-IS=Verkáætlunarlína %1 %2 %3 er ekki vörulína. Aðeins vörulínur er hægt að taka frá.';
        NoUsageLinkErr: Label 'Project planning line %1 %2 %3 has Usage Link off. Reservation needs a usage-linked line.', Comment = '%1 = project no.; %2 = task no.; %3 = line no.; is-IS=Verkáætlunarlína %1 %2 %3 er án notkunartengingar. Frátekning krefst línu með notkunartengingu.';
        CompletedErr: Label 'Project %1 is completed, so its planning lines cannot be reserved.', Comment = '%1 = project no.; is-IS=Verkefni %1 er lokið svo ekki er hægt að taka frá fyrir verkáætlunarlínur þess.';
        ReserveNeverErr: Label 'Reserve is set to Never for item %1 or for the project planning line.', Comment = '%1 = item no.; is-IS=Frátekning er stillt á Aldrei fyrir vöru %1 eða verkáætlunarlínuna.';
        LineExpectedTok: Label 'an item planning line with Usage Link on in an open project', Comment = 'is-IS=vöruáætlunarlína með notkunartengingu í opnu verkefni';
        PreconditionNextStepLbl: Label 'Use an item planning line with Usage Link on in a project that is not completed, or reserve manually.', Comment = 'is-IS=Notaðu vöruáætlunarlínu með notkunartengingu í verkefni sem er ekki lokið, eða taktu frá handvirkt.';
    begin
        if not JobPlanningLine.Get(JobNo, JobTaskNo, PlanningLineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, JobNo, JobTaskNo, PlanningLineNo), 'sourceLineNo', Format(PlanningLineNo, 0, 9), LineExpectedTok, NotFoundNextStepLbl);
            exit(false);
        end;
        if ForReserve then begin
            if (JobPlanningLine.Type <> JobPlanningLine.Type::Item) or (JobPlanningLine."No." = '') then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotItemErr, JobNo, JobTaskNo, PlanningLineNo), 'sourceLineNo', Format(PlanningLineNo, 0, 9), LineExpectedTok, PreconditionNextStepLbl);
                exit(false);
            end;
            Job.SetLoadFields(Status);
            if Job.Get(JobNo) and (Job.Status = Job.Status::Completed) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CompletedErr, JobNo), 'sourceNo', JobNo, LineExpectedTok, PreconditionNextStepLbl);
                exit(false);
            end;
            if not JobPlanningLine."Usage Link" then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoUsageLinkErr, JobNo, JobTaskNo, PlanningLineNo), 'sourceLineNo', Format(PlanningLineNo, 0, 9), LineExpectedTok, PreconditionNextStepLbl);
                exit(false);
            end;
            Item.SetLoadFields(Reserve);
            if (JobPlanningLine.Reserve = JobPlanningLine.Reserve::Never) or (Item.Get(JobPlanningLine."No.") and (Item.Reserve = Item.Reserve::Never)) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ReserveNeverErr, JobPlanningLine."No."), 'sourceLineNo', Format(PlanningLineNo, 0, 9), LineExpectedTok, PreconditionNextStepLbl);
                exit(false);
            end;
        end;
        SourceSubtype := JobPlanningLine.Status.AsInteger();
        ContractEntryNo := JobPlanningLine."Job Contract Entry No.";
        ItemNo := JobPlanningLine."No.";
        LocationCode := JobPlanningLine."Location Code";
        AvailabilityDate := JobPlanningLine."Planning Date";
        QtyPerUOM := JobPlanningLine."Qty. per Unit of Measure";
        Description := JobPlanningLine.Description;
        exit(true);
    end;

    /// <summary>Checks item and sales-line reservation eligibility shared by Create and AutoReserve.</summary>
    procedure CheckSalesLinePolicy(var Argument: Record "Message Argument ori"; SalesLine: Record "Sales Line"): Boolean
    var
        Item: Record Item;
        NotItemErr: Label 'The line is not an item line.', Comment = 'is-IS=Línan er ekki vörulína.';
        NotInventoryErr: Label 'Item %1 is not an inventory item.', Comment = '%1 = item no., is-IS=Vara %1 er ekki birgðavara.';
        ReserveNeverErr: Label 'Reserve is set to Never for item %1 or for the line.', Comment = '%1 = item no., is-IS=Frátekning er stillt á Aldrei fyrir vöru %1 eða línuna.';
        DropShipmentErr: Label 'The line is a drop shipment or special order line.', Comment = 'is-IS=Línan er bein afhending eða sérpöntunarlína.';
        NoShipmentDateErr: Label 'The line has no shipment date.', Comment = 'is-IS=Línan hefur engan afhendingardag.';
        ReservableExpectedLbl: Label 'a reservable item line on a sales order', Comment = 'is-IS=vörulína á sölupöntun sem má taka frá';
        PreconditionNextStepLbl: Label 'Change the item''s Reserve setting or reserve manually.', Comment = 'is-IS=Breyttu stillingunni Frátekning á vörunni eða taktu frá handvirkt.';
    begin
        if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NotItemErr, 'lineNo', Format(SalesLine."Line No.", 0, 9), ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        Item.SetLoadFields(Type, Reserve);
        if not Item.Get(SalesLine."No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotInventoryErr, SalesLine."No."), 'lineNo', SalesLine."No.", ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        if (Item.Reserve = Item.Reserve::Never) or (SalesLine.Reserve = SalesLine.Reserve::Never) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ReserveNeverErr, Item."No."), 'lineNo', Item."No.", ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        if Item.Type <> Item.Type::Inventory then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotInventoryErr, Item."No."), 'lineNo', Item."No.", ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        if SalesLine."Drop Shipment" or SalesLine."Special Order" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, DropShipmentErr, 'lineNo', Format(SalesLine."Line No.", 0, 9), ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        if SalesLine."Shipment Date" = 0D then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoShipmentDateErr, 'lineNo', Format(SalesLine."Line No.", 0, 9), ReservableExpectedLbl, PreconditionNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RespondNotFound(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        NotFoundErr: Label 'The sales line was not found.', Comment = 'is-IS=Sölulínan fannst ekki.';
        NotFoundNextStepLbl: Label 'Check the document and line no.', Comment = 'is-IS=Athugaðu fylgiskjalið og línunúmerið.';
        ExistingLineExpectedLbl: Label 'an existing sales order line', Comment = 'is-IS=sölupöntunarlína sem er til';
    begin
        if RequestJson.Contains('systemId') then
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'systemId', ReadText(RequestJson, 'systemId'), ExistingLineExpectedLbl, NotFoundNextStepLbl)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'documentNo', ReadText(RequestJson, 'documentNo'), ExistingLineExpectedLbl, NotFoundNextStepLbl);
    end;

    local procedure RespondSuccess(var Argument: Record "Message Argument ori"; SalesLine: Record "Sales Line"; Reserved: Decimal; EntriesBefore: List of [Integer])
    var
        ResponseJson: JsonObject;
        Entries: JsonArray;
    begin
        CollectNewEntries(SalesLine, EntriesBefore, Entries);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', OrderTok);
        ResponseJson.Add('documentNo', SalesLine."Document No.");
        ResponseJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson.Add('systemId', Format(SalesLine.SystemId, 0, 4));
        ResponseJson.Add('itemNo', SalesLine."No.");
        ResponseJson.Add('reserved', Reserved);
        ResponseJson.Add('reservedQuantity', SalesLine."Reserved Quantity");
        ResponseJson.Add('outstandingQuantity', SalesLine."Outstanding Quantity");
        ResponseJson.Add('fullyReserved', RemainingBase(SalesLine) <= 0);
        ResponseJson.Add('entries', Entries);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure FilterLineReservations(SalesLine: Record "Sales Line"; var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
    end;

    local procedure CollectReservationEntryNos(SalesLine: Record "Sales Line"; var EntryNos: List of [Integer])
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        FilterLineReservations(SalesLine, ReservationEntry);
        ReservationEntry.SetLoadFields("Entry No.");
        if ReservationEntry.FindSet() then
            repeat
                EntryNos.Add(ReservationEntry."Entry No.");
            until ReservationEntry.Next() = 0;
    end;

    local procedure CollectNewEntries(SalesLine: Record "Sales Line"; EntriesBefore: List of [Integer]; var Entries: JsonArray)
    var
        ReservationEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        EntryJson: JsonObject;
    begin
        FilterLineReservations(SalesLine, ReservationEntry);
        ReservationEntry.SetLoadFields("Entry No.", Positive, "Item No.", Quantity, "Quantity (Base)", "Shipment Date");
        SupplyEntry.SetLoadFields("Source Type", "Source Subtype", "Source ID", "Source Ref. No.");
        if ReservationEntry.FindSet() then
            repeat
                if not EntriesBefore.Contains(ReservationEntry."Entry No.") then begin
                    Clear(EntryJson);
                    EntryJson.Add('entryNo', ReservationEntry."Entry No.");
                    EntryJson.Add('itemNo', ReservationEntry."Item No.");
                    EntryJson.Add('quantity', ReservationEntry.Quantity);
                    EntryJson.Add('quantityBase', ReservationEntry."Quantity (Base)");
                    EntryJson.Add('shipmentDate', Format(ReservationEntry."Shipment Date", 0, 9));
                    if SupplyEntry.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then begin
                        EntryJson.Add('supplyType', SupplyEntry."Source Type");
                        EntryJson.Add('supplyTypeName', TableName(SupplyEntry."Source Type"));
                        EntryJson.Add('supplySubtype', SupplyEntry."Source Subtype");
                        EntryJson.Add('supplyNo', SupplyEntry."Source ID");
                        EntryJson.Add('supplyLineNo', SupplyEntry."Source Ref. No.");
                    end;
                    Entries.Add(EntryJson);
                end;
            until ReservationEntry.Next() = 0;
    end;

    local procedure TableName(TableNo: Integer): Text
    var
        RecRef: RecordRef;
        Name: Text;
    begin
        if TableNo = 0 then
            exit('');
        RecRef.Open(TableNo);
        Name := RecRef.Name();
        RecRef.Close();
        exit(Name);
    end;

    local procedure FindSalesLine(RequestJson: JsonObject; var SalesLine: Record "Sales Line"): Boolean
    var
        LineId: Guid;
        LineNo: Integer;
    begin
        if RequestJson.Contains('systemId') then begin
            if not Evaluate(LineId, ReadText(RequestJson, 'systemId')) then
                exit(false);
            exit(SalesLine.GetBySystemId(LineId));
        end;
        if not Evaluate(LineNo, ReadText(RequestJson, 'lineNo'), 9) then
            exit(false);
        exit(SalesLine.Get(SalesLine."Document Type"::Order, CopyStr(ReadText(RequestJson, 'documentNo'), 1, MaxStrLen(SalesLine."Document No.")), LineNo));
    end;

    local procedure QtyPerUnitOfMeasure(SalesLine: Record "Sales Line"): Decimal
    begin
        if SalesLine."Qty. per Unit of Measure" = 0 then
            exit(1);
        exit(SalesLine."Qty. per Unit of Measure");
    end;

    local procedure RemainingQuantity(SalesLine: Record "Sales Line"): Decimal
    begin
        exit(SalesLine."Outstanding Quantity" - SalesLine."Reserved Quantity");
    end;

    local procedure RemainingBase(SalesLine: Record "Sales Line"): Decimal
    begin
        exit(SalesLine."Outstanding Qty. (Base)" - SalesLine."Reserved Qty. (Base)");
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Result: Decimal;
    begin
        if not Evaluate(Result, ReadText(RequestJson, KeyName), 9) then
            exit(0);
        exit(Result);
    end;
}
