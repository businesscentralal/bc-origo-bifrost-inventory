namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of Inventory.AttributeDefinition.Create.
/// </summary>
codeunit 10076913 "Item AttrDef Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Creates an item attribute definition and optional option values, independent of any item.', Comment = 'is-IS=Býr til skilgreiningu vörueiginleika og valkvæða valkosti, óháð einstökum vörum.';
    begin
        exit(DescriptionLbl);
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
        Attribute: Record "Item Attribute";
        Probe: Record "Item Attribute";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Parts: Codeunit "Inventory Contract Parts ori";
        Resolve: Codeunit "Item Attribute Resolve ori";
        Request: JsonObject;
        OptionObject: JsonObject;
        Token: JsonToken;
        OptionToken: JsonToken;
        NameText: Text;
        TypeText: Text;
        OptionText: Text;
        Serialized: Text;
        OptionNames: List of [Text];
        InvalidTypeErr: Label 'Unknown attribute type %1.', Comment = '%1 = type name; is-IS=Óþekkt gerð eiginleika %1.';
        TypesExpectedTxt: Label 'Option, Text, Integer, Decimal or Date.', Comment = 'is-IS=Option, Text, Integer, Decimal eða Date.';
        TypesNextStepTxt: Label 'Send one documented attribute type name in type.', Comment = 'is-IS=Sendu eitt skjalfest heiti gerðar eiginleika í type.';
        DuplicateErr: Label 'Attribute %1 already exists.', Comment = '%1 = attribute name; is-IS=Eiginleikinn %1 er þegar til.';
        NameExpectedTxt: Label 'A unique attribute name.', Comment = 'is-IS=Einkvæmt heiti eiginleika.';
        NameNextStepTxt: Label 'Read existing attributes and choose a new name or use the existing definition.', Comment = 'is-IS=Lestu eiginleika sem eru til og veldu nýtt heiti eða notaðu fyrirliggjandi skilgreiningu.';
        OptionsErr: Label 'optionValues must be an array of distinct nonempty strings for an Option attribute.', Comment = 'is-IS=optionValues verður að vera fylki aðgreindra strengja sem eru ekki tómir fyrir Option-eiginleika.';
        OptionsExpectedTxt: Label 'An array of distinct text option values.', Comment = 'is-IS=Fylki aðgreindra textagilda valkosta.';
        OptionsNextStepTxt: Label 'Correct every option value before creating the definition.', Comment = 'is-IS=Leiðréttu öll valkostsgildi áður en skilgreiningin er stofnuð.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Attributes, Database::"Item Attribute", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        NameText := Parts.ReadRequestText(Argument, Request, 'name', true, MaxStrLen(Attribute.Name));
        TypeText := Parts.ReadRequestText(Argument, Request, 'type', true, 20);
        Parts.ReadRequestText(Argument, Request, 'unitOfMeasure', false, MaxStrLen(Attribute."Unit of Measure"));
        if (TypeText <> '') and not Resolve.TryParseType(TypeText, Probe) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidTypeErr, TypeText), 'type', TypeText, TypesExpectedTxt, TypesNextStepTxt);
        if NameText <> '' then begin
            Attribute.SetRange(Name, NameText);
            if not Attribute.IsEmpty() then
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DuplicateErr, NameText), 'name', NameText, NameExpectedTxt, NameNextStepTxt);
        end;
        if Request.Get('optionValues', Token) then
            if not Token.IsArray() then begin
                Token.WriteTo(Serialized);
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, OptionsErr, 'optionValues', Serialized, OptionsExpectedTxt, OptionsNextStepTxt);
            end else
                foreach OptionToken in Token.AsArray() do begin
                    Clear(OptionObject);
                    OptionObject.Add('optionValues', OptionToken);
                    OptionText := Parts.ReadRequestText(Argument, OptionObject, 'optionValues', true, 250);
                    if OptionNames.Contains(UpperCase(OptionText)) then
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, OptionsErr, 'optionValues', OptionText, OptionsExpectedTxt, OptionsNextStepTxt);
                    OptionNames.Add(UpperCase(OptionText));
                end;
        if Parts.RespondToProblems(Argument) then
            exit;
        if not Codeunit.Run(Codeunit::"Item AttrDef Create Proc ori", Argument) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'name', NameText, NameExpectedTxt, NameNextStepTxt);
            exit;
        end;
    end;
}
