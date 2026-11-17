namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;

/// <summary>Scopes the requested base quantity to one native worksheet reapplication.</summary>
codeunit 10077034 "Item Appl. Quantity ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        OutboundEntryNo: Integer;
        InboundEntryNo: Integer;
        QuantityToApply: Decimal;

    /// <summary>Sets the exact pair and positive base quantity before binding this instance.</summary>
    procedure SetSelection(OutboundNo: Integer; InboundNo: Integer; Quantity: Decimal)
    begin
        OutboundEntryNo := OutboundNo;
        InboundEntryNo := InboundNo;
        QuantityToApply := Quantity;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnApplyItemLedgEntryOnAfterCalcAppliedQty', '', false, false)]
    local procedure LimitQuantity(OldItemLedgEntry: Record "Item Ledger Entry"; ItemLedgEntry: Record "Item Ledger Entry"; var AppliedQty: Decimal)
    var
        QuantityErr: Label 'Business Central cannot apply the exact requested quantity to the selected entries.', Comment = 'is-IS=Business Central getur ekki jafnað nákvæmlega umbeðið magn við valdar færslur.';
    begin
        if (ItemLedgEntry."Entry No." <> OutboundEntryNo) or (OldItemLedgEntry."Entry No." <> InboundEntryNo) then
            exit;
        if (AppliedQty >= 0) or (Abs(AppliedQty) < QuantityToApply) then
            Error(QuantityErr);
        AppliedQty := -QuantityToApply;
    end;
}
