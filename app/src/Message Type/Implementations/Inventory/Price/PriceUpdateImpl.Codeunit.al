namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.Price.Update. Validates Item.Unit Price. This is not a cost update.
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
        exit('Updates an item unit price.');
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
        Envelope.Add('messageType', 'Inventory.Price.Update');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'unitPrice');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('itemNo', '');
        Response.Add('unitPrice', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'unitPrice is required.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'RecordNotFound');
        ErrorJson.Add('when', 'no item matched the request.');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
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
        Overview := 'Updates the unit price of one item.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Writes Item.Unit Price. It does not change item cost.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        DocumentLookup: Codeunit "Document Lookup ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        UnitPrice: Decimal;
        MissingPriceErr: Label 'unitPrice is required.', Locked = true;
        NoItemErr: Label 'No items found matching the specified criteria.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemPrice, Database::Item, true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not DocumentLookup.FindItemRange(Argument, Item) then
            exit;
        if not Item.FindFirst() then begin
            Argument.RespondWithError(NoItemErr);
            exit;
        end;

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('unitPrice', Token) then begin
            Argument.RespondWithError(MissingPriceErr);
            exit;
        end;
        UnitPrice := Token.AsValue().AsDecimal();
        Item.Validate("Unit Price", UnitPrice);
        Item.Modify(true);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('messageType', 'Inventory.Price.Update');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('unitPrice', Item."Unit Price");
        Argument.SetResponseJson(ResponseJson);
    end;
}
