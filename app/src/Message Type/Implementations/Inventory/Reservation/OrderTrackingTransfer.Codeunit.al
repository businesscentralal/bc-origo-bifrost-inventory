namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;

/// <summary>
/// Lets Inventory.OrderTracking.Get read the order tracking chain of a transfer line. The base application has
/// no order tracking source for transfer lines, so this subscriber sets the reservation entry filter for one
/// side of the line. It is bound manually for the duration of one call and is inactive otherwise.
/// </summary>
codeunit 10036929 "Order Tracking Transfer ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        InboundSide: Boolean;

    /// <summary>
    /// Chooses the side of the transfer line whose tracking is read.
    /// </summary>
    /// <param name="Inbound">True for the receipt side, false for the shipment side.</param>
    procedure SetInbound(Inbound: Boolean)
    begin
        InboundSide := Inbound;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::OrderTrackingManagement, OnSetSourceRecord, '', false, false)]
    local procedure SetTransferLineSource(var SourceRecordVar: Variant; var ReservationEntry: Record "Reservation Entry"; var ItemLedgerEntry2: Record "Item Ledger Entry")
    var
        TransferLine: Record "Transfer Line";
        SourceRecRef: RecordRef;
    begin
        SourceRecRef.GetTable(SourceRecordVar);
        if SourceRecRef.Number <> Database::"Transfer Line" then
            exit;
        // Another subscriber already set a source; do not overwrite it.
        if ReservationEntry.GetFilter("Source Type") <> '' then
            exit;
        TransferLine := SourceRecordVar;
        ReservationEntry.InitSortingAndFilters(false);
        if InboundSide then
            TransferLine.SetReservationFilters(ReservationEntry, "Transfer Direction"::Inbound)
        else
            TransferLine.SetReservationFilters(ReservationEntry, "Transfer Direction"::Outbound);
    end;
}
