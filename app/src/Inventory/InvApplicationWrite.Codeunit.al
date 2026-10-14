namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Origo.Bifrost;

/// <summary>Atomic application worksheet operations, with a scoped native integration event for base quantity.</summary>
codeunit 70013495 "Inv Application Write ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        SelectedInbound: Integer;
        SelectedOutbound: Integer;
        RemainingToApply: Decimal;
        ParameterErr: Label 'Invalid application parameter %1.', Comment = '%1 = parameter name; is-IS=Ógild færibreyta %1 fyrir vörujöfnun.';
        NoApplicationsErr: Label 'The entry has no real application to unapply.', Comment = 'is-IS=Færslan hefur enga raunverulega jöfnun sem hægt er að afturkalla.';
        QuantityErr: Label 'quantity must be positive and within the unreserved remaining base quantity of both entries.', Comment = 'is-IS=quantity verður að vera jákvætt og innan ófrátekins eftirstöðvamagns í grunneiningu beggja færslna.';
        AppliedQuantityErr: Label 'The native worksheet did not apply exactly the requested base quantity.', Comment = 'is-IS=Innbyggða vinnublaðið jafnaði ekki nákvæmlega umbeðið magn í grunneiningu.';

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure Unapply(var Argument: Record "Message Argument ori")
    var
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        NativeApply: Codeunit "Item Jnl.-Post Line";
        Request: JsonObject;
        Response: JsonObject;
        EntryNos: List of [Integer];
        EntryNo: Integer;
        Name: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach Name in Request.Keys() do
            if not (Name in ['itemLedgerEntryNo', 'entryNo']) then
                Error(ParameterErr, Name);
        if Request.Contains('itemLedgerEntryNo') = Request.Contains('entryNo') then
            Error(ParameterErr, 'itemLedgerEntryNo');
        if Request.Contains('entryNo') then begin
            Application.Get(ReadNumber(Request, 'entryNo', true));
            EntryNos.Add(Application."Entry No.");
            Ledger.Get(Application."Item Ledger Entry No.");
        end else begin
            Ledger.Get(ReadNumber(Request, 'itemLedgerEntryNo', true));
            if Ledger.Positive then
                Application.SetRange("Inbound Item Entry No.", Ledger."Entry No.")
            else
                Application.SetRange("Outbound Item Entry No.", Ledger."Entry No.");
            Application.SetFilter("Inbound Item Entry No.", '<>0');
            if Ledger.Positive then
                Application.SetRange("Inbound Item Entry No.", Ledger."Entry No.");
            if Ledger.Positive then
                Application.SetFilter("Outbound Item Entry No.", '<>0');
            if Application.FindSet() then
                repeat
                    EntryNos.Add(Application."Entry No.");
                until Application.Next() = 0;
        end;
        if EntryNos.Count() = 0 then
            Error(NoApplicationsErr);
        NativeApply.SetCalledFromApplicationWorksheet(true);
        foreach EntryNo in EntryNos do begin
            Application.Get(EntryNo);
            NativeApply.UnApply(Application);
            NativeApply.LogUnapply(Application);
            MarkForAdjustment(Application."Inbound Item Entry No.");
            MarkForAdjustment(Application."Outbound Item Entry No.");
        end;
        Response.Add('status', 'Success');
        Response.Add('itemLedgerEntryNo', Ledger."Entry No.");
        Response.Add('unappliedCount', EntryNos.Count());
        Response.Add('adjustmentRequired', true);
        SetResponse(Argument, Response);
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    procedure Reapply(var Argument: Record "Message Argument ori")
    var
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        NativeApply: Codeunit "Item Jnl.-Post Line";
        QuantityLimit: Codeunit "Inv Application Write ori";
        Request: JsonObject;
        Response: JsonObject;
        Quantity: Decimal;
        BeforeInbound: Decimal;
        BeforeOutbound: Decimal;
        Name: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach Name in Request.Keys() do
            if not (Name in ['outboundEntryNo', 'inboundEntryNo', 'quantity', 'itemLedgerEntryNo', 'applyToEntryNo']) then
                Error(ParameterErr, Name);
        if Request.Contains('outboundEntryNo') or Request.Contains('inboundEntryNo') then begin
            if Request.Contains('itemLedgerEntryNo') or Request.Contains('applyToEntryNo') then
                Error(ParameterErr, 'outboundEntryNo');
            Outbound.Get(ReadNumber(Request, 'outboundEntryNo', true));
            Inbound.Get(ReadNumber(Request, 'inboundEntryNo', true));
        end else begin
            Outbound.Get(ReadNumber(Request, 'itemLedgerEntryNo', true));
            Inbound.Get(ReadNumber(Request, 'applyToEntryNo', true));
        end;
        Outbound.TestField(Positive, false);
        Inbound.TestField(Positive, true);
        Outbound.TestField("Item No.", Inbound."Item No.");
        Outbound.TestField("Location Code", Inbound."Location Code");
        Outbound.TestField("Variant Code", Inbound."Variant Code");
        Outbound.TestField(Open, true);
        Inbound.TestField(Open, true);
        Inbound.CalcFields("Reserved Quantity");
        Outbound.CalcFields("Reserved Quantity");
        if Request.Contains('quantity') then
            Quantity := ReadNumber(Request, 'quantity', false)
        else
            if Request.Contains('outboundEntryNo') then
                Error(ParameterErr, 'quantity')
            else
                Quantity := Min(Inbound."Remaining Quantity" - Abs(Inbound."Reserved Quantity"), Abs(Outbound."Remaining Quantity") - Abs(Outbound."Reserved Quantity"));
        if (Quantity <= 0) or (Quantity > Inbound."Remaining Quantity" - Abs(Inbound."Reserved Quantity")) or
           (Quantity > Abs(Outbound."Remaining Quantity") - Abs(Outbound."Reserved Quantity")) then
            Error(QuantityErr);
        BeforeInbound := Inbound."Remaining Quantity";
        BeforeOutbound := Outbound."Remaining Quantity";
        QuantityLimit.SetQuantity(Inbound."Entry No.", Outbound."Entry No.", Quantity);
        BindSubscription(QuantityLimit);
        NativeApply.SetCalledFromApplicationWorksheet(true);
        NativeApply.ReApply(Outbound, Inbound."Entry No.");
        UnbindSubscription(QuantityLimit);
        Inbound.Get(Inbound."Entry No.");
        Outbound.Get(Outbound."Entry No.");
        if (BeforeInbound - Inbound."Remaining Quantity" <> Quantity) or
           (Outbound."Remaining Quantity" - BeforeOutbound <> Quantity) then
            Error(AppliedQuantityErr);
        NativeApply.LogApply(Outbound, Inbound);
        MarkForAdjustment(Inbound."Entry No.");
        MarkForAdjustment(Outbound."Entry No.");
        Response.Add('status', 'Success');
        Response.Add('outboundEntryNo', Outbound."Entry No.");
        Response.Add('inboundEntryNo', Inbound."Entry No.");
        Response.Add('quantity', Quantity);
        Response.Add('adjustmentRequired', true);
        SetResponse(Argument, Response);
    end;

    procedure SetQuantity(Inbound: Integer; Outbound: Integer; Quantity: Decimal)
    begin
        SelectedInbound := Inbound;
        SelectedOutbound := Outbound;
        RemainingToApply := Quantity;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnApplyItemLedgEntryOnAfterCalcAppliedQty', '', false, false)]
    local procedure LimitQuantity(OldItemLedgEntry: Record "Item Ledger Entry"; ItemLedgEntry: Record "Item Ledger Entry"; var AppliedQty: Decimal)
    var
        Quantity: Decimal;
    begin
        if not (((OldItemLedgEntry."Entry No." = SelectedInbound) and (ItemLedgEntry."Entry No." = SelectedOutbound)) or
                ((OldItemLedgEntry."Entry No." = SelectedOutbound) and (ItemLedgEntry."Entry No." = SelectedInbound))) then
            exit;
        Quantity := Min(Abs(AppliedQty), RemainingToApply);
        if AppliedQty < 0 then
            AppliedQty := -Quantity
        else
            AppliedQty := Quantity;
        RemainingToApply -= Quantity;
    end;

    local procedure MarkForAdjustment(EntryNo: Integer)
    var
        Ledger: Record "Item Ledger Entry";
        Item: Record Item;
    begin
        Ledger.Get(EntryNo);
        Ledger.SetAppliedEntryToAdjust(true);
        Item.Get(Ledger."Item No.");
        if Item."Cost is Adjusted" then begin
            Item."Cost is Adjusted" := false;
            Item.Modify();
        end;
    end;

    local procedure ReadNumber(Request: JsonObject; Name: Text; IntegerOnly: Boolean): Decimal
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Decimal;
    begin
        if not Request.Get(Name, Token) or not Token.IsValue() then
            Error(ParameterErr, Name);
        Token.WriteTo(Serialized);
        if not Evaluate(Value, Serialized, 9) then
            Error(ParameterErr, Name);
        if (Value <= 0) or (IntegerOnly and ((Value > 2147483647) or (Value <> Round(Value, 1)))) then
            Error(ParameterErr, Name);
        exit(Value);
    end;

    local procedure Min(First: Decimal; Second: Decimal): Decimal
    begin
        if First < Second then
            exit(First);
        exit(Second);
    end;

    local procedure SetResponse(var Argument: Record "Message Argument ori"; Response: JsonObject)
    begin
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
