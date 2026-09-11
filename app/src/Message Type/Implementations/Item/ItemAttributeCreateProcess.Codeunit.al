namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Isolated write process for Item.Attribute.Create. TableNo = Message Argument ori.
/// </summary>
codeunit 10036905 "Item Attr. Create Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Item: Record Item;
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        Resolve: Codeunit "Item Attribute Resolve ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ResultsArray: JsonArray;
        ResultJson: JsonObject;
        AttributesArray: JsonArray;
        AttrToken: JsonToken;
        AttrRequest: JsonObject;
        AllowBlocked: Boolean;
        Overwrite: Boolean;
        CreateValueIfMissing: Boolean;
        Changed: Boolean;
        i: Integer;
    begin
        if not Resolve.ResolveSingleItem(Rec, Item) then
            exit;

        RequestJson := Rec.GetRequestJson();
        AllowBlocked := Resolve.GetBool(RequestJson, 'allowBlocked', false);
        Resolve.AssertItemWritable(Item, AllowBlocked);
        Resolve.GetAttributesArray(RequestJson, AttributesArray);

        for i := 0 to AttributesArray.Count() - 1 do begin
            AttributesArray.Get(i, AttrToken);
            if not AttrToken.IsObject() then
                Error('Each attributes[] element must be an object.');
            AttrRequest := AttrToken.AsObject();
            Resolve.ResolveAttributeFromRequest(AttrRequest, ItemAttribute);
            CreateValueIfMissing := Resolve.GetBool(AttrRequest, 'createValueIfMissing', false);
            Overwrite := Resolve.GetBool(AttrRequest, 'overwrite', false);
            Clear(ItemAttributeValue);
            Resolve.EnsureAttributeValue(ItemAttribute, AttrRequest, CreateValueIfMissing, ItemAttributeValue);
            Clear(ResultJson);
            Resolve.AssignMapping(Item, ItemAttribute, ItemAttributeValue, Overwrite, Changed, ResultJson);
            ResultsArray.Add(ResultJson);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('results', ResultsArray);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
