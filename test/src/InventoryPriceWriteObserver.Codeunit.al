namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;

/// <summary>Observes native price validation and injects a transactional failure only for an owned fixture.</summary>
codeunit 96940 "Inventory Price Write Observer"
{
    EventSubscriberInstance = Manual;

    var
        TargetItemNo: Code[20];
        FailValidation: Boolean;
        ValidationCount: Integer;

    /// <summary>Scopes validation observation to one owned item.</summary>
    procedure SetItem(ItemNo: Code[20]; Fail: Boolean)
    begin
        TargetItemNo := ItemNo;
        FailValidation := Fail;
    end;

    /// <summary>Returns actual Unit Price Validate callbacks.</summary>
    procedure Validations(): Integer
    begin
        exit(ValidationCount);
    end;

    [EventSubscriber(ObjectType::Table, Database::Item, OnAfterValidateEvent, 'Unit Price', false, false)]
    local procedure ObservePrice(var Rec: Record Item; var xRec: Record Item; CurrFieldNo: Integer)
    begin
        if Rec."No." <> TargetItemNo then
            exit;
        ValidationCount += 1;
        if FailValidation then begin
            Rec.Description := 'Owned price subscriber write';
            Rec.Modify(false);
            Error('Owned native price validation failure.');
        end;
    end;
}
