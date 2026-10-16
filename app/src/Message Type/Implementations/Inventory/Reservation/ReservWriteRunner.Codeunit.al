namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;

/// <summary>
/// Isolated writer for reservation AutoReserve and cancel. Dispatcher ProcessIncomingMessage is a
/// TryFunction, so INSERT/DELETE must run through Codeunit.Run after Commit.
/// </summary>
codeunit 70013479 "Reserv. Write Runner ori"
{
    Access = Internal;

    var
        ReservationEntry: Record "Reservation Entry";
        ReservationManagement: Codeunit "Reservation Management";
        AvailabilityDate: Date;
        Quantity: Decimal;
        QuantityBase: Decimal;
        FullAutoReservation: Boolean;
        HasCancelEntry: Boolean;
        Mode: Option Reserve,Cancel;
        Description: Text[100];

    trigger OnRun()
    begin
        case Mode of
            Mode::Reserve:
                ReservationManagement.AutoReserve(FullAutoReservation, Description, AvailabilityDate, Quantity, QuantityBase);
            Mode::Cancel:
                if HasCancelEntry then begin
                    ReservationManagement.SetReservSource(ReservationEntry);
                    ReservationManagement.DeleteReservEntries(true, 0);
                    ReservationEntry.SetRange("Entry No.", ReservationEntry."Entry No.");
                    if not ReservationEntry.IsEmpty() then
                        ReservationEntry.DeleteAll(true);
                end else
                    ReservationManagement.DeleteReservEntries(true, 0);
        end;
    end;

    internal procedure SetReserve(var ReservMgt: Codeunit "Reservation Management"; NewDescription: Text[100]; NewAvailabilityDate: Date; NewQuantity: Decimal; NewQuantityBase: Decimal)
    begin
        Mode := Mode::Reserve;
        ReservationManagement := ReservMgt;
        Description := NewDescription;
        AvailabilityDate := NewAvailabilityDate;
        Quantity := NewQuantity;
        QuantityBase := NewQuantityBase;
        FullAutoReservation := false;
    end;

    internal procedure SetCancel(var ReservMgt: Codeunit "Reservation Management"; CancelEntry: Record "Reservation Entry")
    begin
        Mode := Mode::Cancel;
        ReservationManagement := ReservMgt;
        ReservationEntry := CancelEntry;
        HasCancelEntry := true;
    end;

    internal procedure GetFullAutoReservation(): Boolean
    begin
        exit(FullAutoReservation);
    end;
}
