namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

/// <summary>Restricts one explicitly bound native inventory reservation to the caller's selected supply entry.</summary>
codeunit 10077030 "Reserv. Supply Filter ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        SupplyEntryNo: Integer;

    /// <summary>Selects the only item ledger entry the bound native reservation may consume.</summary>
    /// <param name="EntryNo">The selected existing inventory entry number.</param>
    procedure SetSupplyEntry(EntryNo: Integer)
    begin
        SupplyEntryNo := EntryNo;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Management", 'OnAutoReserveItemLedgEntryOnFindFirstItemLedgEntry', '', false, false)]
    local procedure FilterSelectedSupply(CalcReservEntry: Record "Reservation Entry"; var CalcItemLedgEntry: Record "Item Ledger Entry"; var InvSearch: Text[1]; var IsHandled: Boolean; var IsFound: Boolean)
    begin
        CalcItemLedgEntry.SetRange("Entry No.", SupplyEntryNo);
    end;
}
