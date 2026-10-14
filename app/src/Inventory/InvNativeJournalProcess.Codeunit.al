namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Isolates native journal posting and preserves the caller's transaction policy.</summary>
codeunit 70013469 "Inv Native Journal Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        JournalType: Enum "Item Journal Template Type";

    trigger OnRun()
    var
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        Journal.Post(Rec, JournalType);
    end;

    /// <summary>Selects the dedicated native journal family before Run.</summary>
    procedure SetJournalType(NewJournalType: Enum "Item Journal Template Type")
    begin
        JournalType := NewJournalType;
    end;
}
