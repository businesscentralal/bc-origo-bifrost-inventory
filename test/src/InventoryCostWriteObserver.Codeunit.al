namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Transfer;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;

/// <summary>Observes actual Item validation and injects one native subscriber failure only for an explicitly selected owned test item.</summary>
codeunit 96938 "Inventory Cost Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        TargetShipmentNo: Code[20];
        TargetAssemblyNo: Code[20];
        UndoLineCount: Integer;
        TargetItemNo: Code[20];
        FailValidation: Boolean;
        UnitCostCount: Integer;
        DirectCostCount: Integer;

    /// <summary>Injects an undo failure after native writes in one explicitly owned posted document.</summary>
    procedure SetUndoFailure(ShipmentNo: Code[20]; AssemblyNo: Code[20])
    begin
        TargetShipmentNo := ShipmentNo;
        TargetAssemblyNo := AssemblyNo;
        UndoLineCount := 0;
    end;

    /// <summary>Counts actual native undo line callbacks before failure.</summary>
    procedure UndoCallbacks(): Integer
    begin
        exit(UndoLineCount);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Transfer Shipment", OnBeforeModifyTransShptLine, '', false, false)]
    local procedure FailSecondUndoLine(var TransferShipmentLine: Record "Transfer Shipment Line")
    begin
        if (TargetShipmentNo = '') or (TransferShipmentLine."Document No." <> TargetShipmentNo) then
            exit;
        UndoLineCount += 1;
        if UndoLineCount = 2 then
            Error('Owned second undo line failure.');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", OnAfterUndoPost, '', false, false)]
    local procedure FailAfterAssemblyUndo(var PostedAssemblyHeader: Record "Posted Assembly Header"; SuppressCommit: Boolean)
    begin
        if (TargetAssemblyNo <> '') and (PostedAssemblyHeader."No." = TargetAssemblyNo) then
            Error('Owned assembly undo failure.');
    end;

    /// <summary>Scopes observation and optional failure to the self-created test item.</summary>
    procedure SetItem(ItemNo: Code[20]; Fail: Boolean)
    begin
        TargetItemNo := ItemNo;
        FailValidation := Fail;
    end;

    /// <summary>Returns real Unit Cost validation callbacks.</summary>
    procedure UnitCostValidations(): Integer
    begin
        exit(UnitCostCount);
    end;

    /// <summary>Returns real Last Direct Cost validation callbacks.</summary>
    procedure DirectCostValidations(): Integer
    begin
        exit(DirectCostCount);
    end;

    [EventSubscriber(ObjectType::Table, Database::Item, OnAfterValidateEvent, 'Unit Cost', false, false)]
    local procedure ObserveUnitCost(var Rec: Record Item; var xRec: Record Item; CurrFieldNo: Integer)
    begin
        if Rec."No." = TargetItemNo then
            UnitCostCount += 1;
    end;

    [EventSubscriber(ObjectType::Table, Database::Item, OnAfterValidateEvent, 'Last Direct Cost', false, false)]
    local procedure ObserveDirectCost(var Rec: Record Item; var xRec: Record Item; CurrFieldNo: Integer)
    begin
        if Rec."No." <> TargetItemNo then
            exit;
        DirectCostCount += 1;
        if FailValidation then begin
            Rec.Description := 'Owned test subscriber change';
            Rec.Modify(false);
            Error('Owned native cost validation failure.');
        end;
    end;
}
