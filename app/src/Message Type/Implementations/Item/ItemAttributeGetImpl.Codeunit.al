namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of Inventory.Attribute.Get.
/// </summary>
codeunit 10036897 "Item Attribute Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Attributes, GetFilterTableNo(), false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns item attribute definitions and assigned values for one or more items.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'read item attributes, get item attribute values, inspect item characteristics, list assigned attributes, item metadata', Comment = 'is-IS=lesa eiginleika vöru, sækja eiginleikagildi vöru, skoða eiginleika vöru, telja úthlutaða eiginleika, lýsigögn vöru';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reads item attributes and assigned values without changing the item; use Inventory.Attribute.Create to assign a value.', Comment = 'is-IS=Les eiginleika vöru og úthlutuð gildi án þess að breyta vörunni; notaðu Inventory.Attribute.Create til að úthluta gildi.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := ContractParts.GetEnvelope('Inventory.Attribute.Get');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := ContractParts.GetTarget('Inventory.Attribute.Get');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Parameters := ContractParts.GetParameters('Inventory.Attribute.Get');
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := ContractParts.GetResponse('Inventory.Attribute.Get');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := ContractParts.GetErrors('Inventory.Attribute.Get');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := ContractParts.GetEffect('Inventory.Attribute.Get');
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
        Related := ContractParts.GetRelated('Inventory.Attribute.Get');
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
        Examples := ContractParts.GetExamples('Inventory.Attribute.Get');
        exit(Examples.Count() > 0);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := ContractParts.GetOverview('Inventory.Attribute.Get');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        ContractParts: Codeunit "Inventory Contract Parts ori";
    begin
        Notes := ContractParts.GetNotes('Inventory.Attribute.Get');
        exit(Notes <> '');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Item: Record Item;
        DocumentLookup: Codeunit "Document Lookup ori";
        Resolve: Codeunit "Item Attribute Resolve ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemsArray: JsonArray;
        ItemJson: JsonObject;
        AttributesArray: JsonArray;
        NameFilter: List of [Text];
        IdFilter: List of [Integer];
        IncludeUnassigned: Boolean;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Attributes, GetFilterTableNo(), false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        if not DocumentLookup.FindItemRange(Argument, Item) then
            exit;

        RequestJson := Argument.GetRequestJson();
        Resolve.ParseGetFilters(RequestJson, NameFilter, IdFilter, IncludeUnassigned);

        if Item.FindSet() then
            repeat
                Clear(AttributesArray);
                Clear(ItemJson);
                Resolve.CollectItemAttributes(Item, NameFilter, IdFilter, IncludeUnassigned, AttributesArray);
                ItemJson.Add('itemNo', Item."No.");
                ItemJson.Add('itemSystemId', Format(Item.SystemId, 0, 4));
                ItemJson.Add('attributes', AttributesArray);
                ItemsArray.Add(ItemJson);
            until Item.Next() = 0;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('items', ItemsArray);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
