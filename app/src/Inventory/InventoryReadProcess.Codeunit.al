namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;

/// <summary>Preserves structured errors at the public read and rollback-preview dispatch boundary.</summary>
codeunit 10076926 "Inventory Read Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Operation: Text;
        UnknownOperationErr: Label 'Unknown inventory read operation.', Comment = 'is-IS=Óþekkt birgðalesaðgerð.';

    trigger OnRun()
    var
        Journal: Codeunit "Inventory Native Journal ori";
    begin
        case Operation of
            'PhysicalCheck':
                Journal.Check(Rec, "Item Journal Template Type"::"Phys. Inventory");
            'PhysicalPreview':
                Journal.Preview(Rec, "Item Journal Template Type"::"Phys. Inventory");
            'RevaluationPreview':
                Journal.PreviewRevaluation(Rec);
            else
                Error(UnknownOperationErr);
        end;
    end;

    /// <summary>Selects the read-only check or native rollback preview; the caller preserves its existing permission gates.</summary>
    procedure SetOperation(NewOperation: Text)
    begin
        Operation := NewOperation;
    end;
}
