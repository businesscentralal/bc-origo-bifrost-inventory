namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Item.Attribute.Create message type (Inbound).
/// Writes run through <c>Item Attr. Create Process ori</c> for error isolation.
/// </summary>
codeunit 10036898 "Item Attribute Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Mapping: Record "Item Attribute Value Mapping";
    begin
        exit(Mapping.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assigns attribute values to an item. Idempotent when the same value already exists.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assign item attribute, create item attribute value, set item characteristic, tag item, add item metadata', Comment = 'is-IS=úthluta eiginleika vöru, búa til eiginleikagildi vöru, stilla eiginleika vöru, merkja vöru, bæta við lýsigögnum vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Assigns attribute values to an item and may create missing option values; use Item.Attribute.Update for an existing mapping.', Comment = 'is-IS=Úthlutar eiginleikagildum á vöru og getur búið til valkosti sem vantar; notaðu Item.Attribute.Update fyrir núverandi vörutengingu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := ContractParts.GetTarget('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Item.Attribute.Create');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Related := ContractParts.GetRelated('Item.Attribute.Create');
        exit(true);
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
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Item.Attribute.Create');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := ContractParts.GetNotes('Item.Attribute.Create');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Codeunit.Run(Codeunit::"Item Attr. Create Process ori", Argument) then begin
            Argument.RespondWithLastError();
            exit;
        end;
    end;
}
