namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of Inventory.AttributeDefinition.Create.
/// </summary>
codeunit 10036900 "Item AttrDef Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Attributes, Database::"Item Attribute", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Attribute");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates an item attribute definition and optional option values, independent of any item.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create item attribute definition, define item characteristic, add attribute type, create option list, item metadata definition', Comment = 'is-IS=búa til eiginleikaskilgreiningu vöru, skilgreina eiginleika vöru, bæta við eiginleikategund, búa til valkostalista, skilgreining á lýsigögnum vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Creates a reusable item attribute definition and optional option values; use Inventory.Attribute.Create to assign it to an item.', Comment = 'is-IS=Býr til endurnýtanlega eiginleikaskilgreiningu vöru og valkvæða valkosti; notaðu Inventory.Attribute.Create til að úthluta henni á vöru.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Inventory.AttributeDefinition.Create');
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
        Related := ContractParts.GetRelated('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Examples := ContractParts.GetExamples('Inventory.AttributeDefinition.Create');
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Inventory.AttributeDefinition.Create');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Attributes, Database::"Item Attribute", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Codeunit.Run(Codeunit::"Item AttrDef Create Proc ori", Argument) then begin
            Argument.RespondWithLastError();
            exit;
        end;
    end;
}
