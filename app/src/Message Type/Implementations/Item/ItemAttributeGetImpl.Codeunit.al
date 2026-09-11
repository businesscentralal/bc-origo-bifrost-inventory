namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Item.Attribute.Get message type (Outbound).
/// </summary>
codeunit 10036897 "Item Attribute Get Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Returns item attribute definitions and assigned values for one or more items.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Item Attribute Get Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
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
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        if not Argument.FindItemRange(Item) then
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
