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
        Operation: Text;

    trigger OnRun()
    var
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        case Operation of
            'Calculate':
                Journal.Calculate(Rec);
            'RecordCount':
                Journal.RecordCount(Rec);
            else
                Journal.Post(Rec, JournalType);
        end;
    end;

    /// <summary>Selects the native Calculate or RecordCount write path; blank means Post.</summary>
    procedure SetOperation(NewOperation: Text)
    begin
        Operation := NewOperation;
    end;

    /// <summary>Selects the dedicated native journal family before Run.</summary>
    procedure SetJournalType(NewJournalType: Enum "Item Journal Template Type")
    begin
        JournalType := NewJournalType;
    end;
}
