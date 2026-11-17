namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Provides one atomic transaction for bounded requisition planning and carry-out.</summary>
codeunit 10076943 "Requisition Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Operation: Text;

    trigger OnRun()
    begin
        RunOperation(Rec);
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunOperation(var Argument: Record "Message Argument ori")
    var
        Worksheet: Codeunit "Requisition Worksheet ori";
    begin
        case Operation of
            'Calculate':
                Worksheet.CalculateRequest(Argument);
            'CarryOut':
                Worksheet.CarryOutRequest(Argument);
        end;
    end;

    /// <summary>Selects native order creation instead of calculation.</summary>
    procedure SetOperation(NewOperation: Text)
    begin
        Operation := NewOperation;
    end;
}
