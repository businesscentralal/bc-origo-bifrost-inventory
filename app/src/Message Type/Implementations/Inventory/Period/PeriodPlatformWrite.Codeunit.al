namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;

/// <summary>
/// Writes inventory period close and reopen rows the same way as codeunit 5820 Close Inventory Period.
/// Running that codeunit is a nested try function under ExecuteBifrostTask, and Business Central then
/// refuses the inventory period entry insert. These procedures are ordinary calls, so the insert stays
/// in the caller's transaction. There is no Commit and no StartSession.
/// </summary>
codeunit 10076928 "Period Platform Write ori"
{
    Access = Internal;
    Permissions = tabledata "Inventory Period" = rimd,
                  tabledata "Inventory Period Entry" = rimd;

    /// <summary>
    /// Closes the period and every earlier open inventory period, and writes a Close entry for each.
    /// </summary>
    /// <param name="InventoryPeriod">The open inventory period to close.</param>
    procedure ApplyClose(var InventoryPeriod: Record "Inventory Period")
    begin
        Apply(InventoryPeriod, false);
    end;

    /// <summary>
    /// Reopens the period and every later closed inventory period, and writes a Re-open entry for each.
    /// </summary>
    /// <param name="InventoryPeriod">The closed inventory period to reopen.</param>
    procedure ApplyReopen(var InventoryPeriod: Record "Inventory Period")
    begin
        Apply(InventoryPeriod, true);
    end;

    local procedure Apply(var InventoryPeriod: Record "Inventory Period"; Reopen: Boolean)
    var
        RelatedPeriod: Record "Inventory Period";
        PeriodToChange: Record "Inventory Period";
    begin
        RelatedPeriod.SetRange(Closed, Reopen);
        if Reopen then
            RelatedPeriod.SetFilter("Ending Date", '>%1', InventoryPeriod."Ending Date")
        else
            RelatedPeriod.SetFilter("Ending Date", '<%1', InventoryPeriod."Ending Date");
        if RelatedPeriod.FindSet(true) then
            repeat
                PeriodToChange := RelatedPeriod;
                PeriodToChange.Closed := not Reopen;
                PeriodToChange.Modify();
                InsertPeriodEntry(PeriodToChange);
            until RelatedPeriod.Next() = 0;

        InventoryPeriod.Closed := not Reopen;
        InventoryPeriod.Modify();
        InsertPeriodEntry(InventoryPeriod);
    end;

    local procedure InsertPeriodEntry(InventoryPeriod: Record "Inventory Period")
    var
        PeriodEntry: Record "Inventory Period Entry";
        ItemRegister: Record "Item Register";
        EntryNo: Integer;
    begin
        PeriodEntry.SetRange("Ending Date", InventoryPeriod."Ending Date");
        if PeriodEntry.FindLast() then
            EntryNo := PeriodEntry."Entry No." + 1
        else
            EntryNo := 1;

        PeriodEntry.Init();
        PeriodEntry."Entry No." := EntryNo;
        PeriodEntry."Ending Date" := InventoryPeriod."Ending Date";
        PeriodEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(PeriodEntry."User ID"));
        PeriodEntry."Creation Date" := WorkDate();
        PeriodEntry."Creation Time" := Time;
        if InventoryPeriod.Closed then begin
            PeriodEntry."Entry Type" := PeriodEntry."Entry Type"::Close;
            if ItemRegister.FindLast() then
                PeriodEntry."Closing Item Register No." := ItemRegister."No.";
        end else
            PeriodEntry."Entry Type" := PeriodEntry."Entry Type"::"Re-open";
        PeriodEntry.Insert();
    end;
}
