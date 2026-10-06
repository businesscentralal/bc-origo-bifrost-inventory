namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.Price.Update. Validates Item.Unit Price. This is not Inventory.Cost.Update.
/// </summary>
codeunit 70013486 "Price Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemPrice, Database::Item, true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Updates an item unit price or a price list line unit price.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('update item price, unit price');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Updates a sales price. Cost updates stay Inventory.Cost.Update.');
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
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemPrice, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ResponseJson.Add('status', 'Accepted');
        ResponseJson.Add('messageType', 'Inventory.Price.Update');
        Argument.SetResponseJson(ResponseJson);
    end;
}
