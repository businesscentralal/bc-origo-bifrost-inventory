namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Inventory.Attribute.Update message type (Inbound).
/// </summary>
codeunit 10036899 "Item Attribute Update Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Attributes, Database::"Item Attribute Value Mapping", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Updates an existing item attribute mapping and returns before/after values.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'update item attribute, change item attribute value, replace item characteristic, edit item metadata, overwrite item attribute', Comment = 'is-IS=uppfæra eiginleika vöru, breyta eiginleikagildi vöru, skipta um eiginleika vöru, breyta lýsigögnum vöru, skrifa yfir eiginleika vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Updates an existing item attribute mapping and returns before and after values; use Inventory.Attribute.Create when no mapping exists.', Comment = 'is-IS=Uppfærir núverandi eiginleikatengingu vöru og skilar fyrra og nýju gildi; notaðu Inventory.Attribute.Create þegar tenging er ekki til.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Inventory.Attribute.Update');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := ContractParts.GetTarget('Inventory.Attribute.Update');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Inventory.Attribute.Update');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Inventory.Attribute.Update');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Inventory.Attribute.Update');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Inventory.Attribute.Update');
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
        Related := ContractParts.GetRelated('Inventory.Attribute.Update');
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
        Overview := ContractParts.GetOverview('Inventory.Attribute.Update');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := ContractParts.GetNotes('Inventory.Attribute.Update');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Attributes, Database::"Item Attribute Value Mapping", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Codeunit.Run(Codeunit::"Item Attr. Update Process ori", Argument) then begin
            Argument.RespondWithLastError();
            exit;
        end;
    end;
}
