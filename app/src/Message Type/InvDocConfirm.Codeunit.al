namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

/// <summary>
/// Counts one inventory document only after the same validation the handler uses.
/// An unknown document or an order with no lines is refused here, so confirmation is not asked first.
/// </summary>
codeunit 10076952 "Inv. Doc Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        DocumentNo: Code[20];
        Ready: Boolean;
        SummaryLbl: Label 'record %1', Comment = '%1 = document or selection, is-IS=færsla %1';
    begin
        case Argument.Type of
            "Message Type ori"::"Inventory.Transfer.UndoShipment":
                Ready := UndoShipmentReady(Argument, DocumentNo);
            "Message Type ori"::"Inventory.TransferOrder.Ship":
                Ready := TransferShipReady(Argument, true, DocumentNo);
            "Message Type ori"::"Inventory.TransferOrder.Receive":
                Ready := TransferShipReady(Argument, false, DocumentNo);
            "Message Type ori"::"Inventory.TransferOrder.Post":
                Ready := TransferPostReady(Argument, DocumentNo);
            "Message Type ori"::"Inventory.AssemblyOrder.Post":
                Ready := AssemblyPostReady(Argument, DocumentNo);
            "Message Type ori"::"Inventory.Assembly.UndoPost":
                Ready := AssemblyUndoReady(Argument, DocumentNo);
            "Message Type ori"::"Inventory.PhysInventoryOrder.Post":
                Ready := PhysOrderReady(Argument, DocumentNo);
            "Message Type ori"::"Inventory.Reclassification.Post":
                Ready := ReclassReady(Argument);
            "Message Type ori"::"Inventory.PhysInventory.Post":
                Ready := PhysJournalReady(Argument);
            "Message Type ori"::"Inventory.Revaluation.Post":
                Ready := RevalReady(Argument);
            "Message Type ori"::"Inventory.AdjustCost.Run":
                Ready := AdjustCostReady(Argument);
            "Message Type ori"::"Inventory.CostToGL.Post":
                Ready := CostToGLReady(Argument);
            "Message Type ori"::"Sales.Shipment.Undo":
                Ready := PostedUndoReady(Argument, true);
            "Message Type ori"::"Purchase.Receipt.Undo":
                Ready := PostedUndoReady(Argument, false);
            else
                Ready := false;
        end;
        if not Ready then
            exit(false);
        if DocumentNo = '' then
            DocumentNo := CopyStr(Argument.Subject, 1, MaxStrLen(DocumentNo));
        Count := 1;
        Summary := StrSubstNo(SummaryLbl, DocumentNo);
        exit(true);
    end;

    local procedure UndoShipmentReady(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]): Boolean
    var
        UndoShipment: Codeunit "Transfer Undo Shpt Impl ori";
    begin
        exit(UndoShipment.ValidateForConfirm(Argument, DocumentNo));
    end;

    local procedure TransferShipReady(var Argument: Record "Message Argument ori"; Ship: Boolean; var DocumentNo: Code[20]): Boolean
    var
        PartialTransfer: Codeunit "Partial Transfer Mgt ori";
    begin
        exit(PartialTransfer.ValidateForConfirm(Argument, Ship, DocumentNo));
    end;

    local procedure TransferPostReady(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]): Boolean
    var
        TransferHeader: Record "Transfer Header";
        TransferPost: Codeunit "Transfer Order Post Impl ori";
        PostingTypeText: Text;
        DirectTransfer: Boolean;
        PostShipment: Boolean;
        PostReceipt: Boolean;
        PostTransfer: Boolean;
    begin
        exit(TransferPost.ValidateForConfirm(Argument, TransferHeader, PostShipment, PostReceipt, PostTransfer, PostingTypeText, DocumentNo, DirectTransfer));
    end;

    local procedure AssemblyPostReady(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]): Boolean
    var
        AssemblyHeader: Record "Assembly Header";
        AssemblyPost: Codeunit "Assembly Order Post Impl ori";
        PostingDate: Date;
        QuantityToAssemble: Decimal;
        ReplacePostingDate: Boolean;
    begin
        if not AssemblyPost.ValidateForConfirm(Argument, AssemblyHeader, PostingDate, QuantityToAssemble, ReplacePostingDate) then
            exit(false);
        DocumentNo := AssemblyHeader."No.";
        exit(true);
    end;

    local procedure AssemblyUndoReady(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]): Boolean
    var
        AssemblyUndo: Codeunit "Assembly Undo Post Impl ori";
        RecreateOrder: Boolean;
    begin
        exit(AssemblyUndo.ValidateForConfirm(Argument, DocumentNo, RecreateOrder));
    end;

    local procedure PhysOrderReady(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]): Boolean
    var
        Process: Codeunit "Phys Order Process ori";
    begin
        if not Process.ValidatePostForConfirm(Argument) then
            exit(false);
        DocumentNo := CopyStr(Argument.Subject, 1, MaxStrLen(DocumentNo));
        exit(true);
    end;

    local procedure ReclassReady(var Argument: Record "Message Argument ori"): Boolean
    var
        ReclassPost: Codeunit "Reclass Post Impl ori";
    begin
        exit(ReclassPost.ValidateForConfirm(Argument));
    end;

    local procedure PhysJournalReady(var Argument: Record "Message Argument ori"): Boolean
    var
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        exit(Journal.ConfirmPhysicalPost(Argument));
    end;

    local procedure RevalReady(var Argument: Record "Message Argument ori"): Boolean
    var
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        exit(Journal.ConfirmRevaluationPost(Argument));
    end;

    local procedure AdjustCostReady(var Argument: Record "Message Argument ori"): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Adjust Cost Run Process ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit(false);
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        exit(Process.ValidateForConfirm(Argument));
    end;

    local procedure CostToGLReady(var Argument: Record "Message Argument ori"): Boolean
    var
        CostToGL: Codeunit "Cost To GL Post Impl ori";
    begin
        exit(CostToGL.ValidateForConfirm(Argument));
    end;

    local procedure PostedUndoReady(var Argument: Record "Message Argument ori"; Sales: Boolean): Boolean
    var
        PostedUndo: Codeunit "Posted Line Undo ori";
    begin
        exit(PostedUndo.ValidateForConfirm(Argument, Sales));
    end;
}
