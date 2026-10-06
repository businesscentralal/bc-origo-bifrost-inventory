namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.AdjustCost.Run. Runs report 795 with the same filters as the job queue request page.
/// </summary>
codeunit 70013460 "Adjust Cost Run Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, true, true));
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Process: Codeunit "Adjust Cost Run Process ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        Process.RunAdjustCost(Argument);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Run Adjust Cost - Item Entries for a filtered set of items, and optionally post the corrections to the general ledger.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('adjust cost,item entry correction,post to g/l,report 795');
    end;
}
