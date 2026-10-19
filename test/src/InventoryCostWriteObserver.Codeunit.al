namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;

/// <summary>Observes actual Item validation and injects one native subscriber failure only for an explicitly selected owned test item.</summary>
codeunit 96938 "Inventory Cost Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        TargetItemNo: Code[20];
        FailValidation: Boolean;
        UnitCostCount: Integer;
        DirectCostCount: Integer;

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
