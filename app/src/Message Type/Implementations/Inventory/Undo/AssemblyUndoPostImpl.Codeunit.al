namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.History;
using Origo.Bifrost;

/// <summary>
/// Inventory.Assembly.UndoPost. Calls Assembly-Post.Undo. Does not delete the posted assembly order.
/// </summary>
codeunit 70013482 "Assembly Undo Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Posted Assembly Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Undoes a posted assembly order by writing corrective item ledger entries.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('undo assembly, reverse assembly');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Undoes a posted assembly order. Optional recreateOrder asks standard to recreate the order.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ResponseJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Posted Assembly Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ResponseJson.Add('status', 'Accepted');
        ResponseJson.Add('messageType', 'Inventory.Assembly.UndoPost');
        Argument.SetResponseJson(ResponseJson);
    end;
}
