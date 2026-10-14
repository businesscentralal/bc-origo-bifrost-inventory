namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.Price.Update. Validates Item.Unit Price. This is not a cost update.
/// </summary>
codeunit 70013486 "Price Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemPrice, Database::Item, true, false));
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Updates an item unit price.');
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetKeywords(): Text
    begin
        exit('update item price, unit price');
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Updates a sales price. Cost updates stay Inventory.Cost.Update.');
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"optional","forms":["itemNo","systemId"],"description":"Exactly one item; Foundation subject precedence applies."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item');
        Target.Add(TargetJson);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Clear(Parameters);
        Parameters.ReadFrom('[{"name":"itemNo","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"itemId","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"id","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"systemId","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"recordSystemId","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"tableView","type":"string","required":false,"description":"Nonempty native Item selection; must resolve exactly one item."},{"name":"unitPrice","type":"decimal","required":true,"description":"Native Item Unit Price; JSON number or invariant decimal string."},{"name":"allowBlocked","type":"boolean","required":false,"description":"Explicitly permit a blocked item; default false."}]');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Clear(Response);
        Response.ReadFrom('{"status":"Success","messageType":"Inventory.Price.Update","itemNo":"","itemId":"","previousUnitPrice":0,"unitPrice":0}');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Clear(Errors);
        Errors.ReadFrom('[{"code":"MissingParameter","when":"unitPrice is absent."},{"code":"InvalidParameter","when":"Malformed or unsupported parameter."},{"code":"RecordNotFound","when":"Item selection finds nothing."},{"code":"PermissionDenied","when":"Native Item or Unit Price field permission refuses the caller."},{"code":"PreconditionFailed","when":"Selection is ambiguous, item is blocked without opt-in or native validation fails."}]');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Update one item price","request":{"type":"Inventory.Price.Update","subject":"OWNED-ITEM","data":{"unitPrice":25}}}]');
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Updates the unit price of one item.';
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Requires one explicit item selection, native Item and Unit Price field access, and unitPrice. Unsupported fields refuse. Uses Validate and Modify in a Codeunit.Run boundary. Writes no price list or inventory revaluation. Normal licensing and company setup apply.';
        exit(true);
    end;

    /// <summary>Provides the guarded single-item price contract.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs the licensed native price transaction.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemPrice, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Inv. Price Write Process ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Inv. Price Write Process ori", Argument) then
                Argument.RespondWithError(GetLastErrorText());
    end;
}
