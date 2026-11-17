namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.NonstockItem.Create, run through Codeunit.Run so a failure rolls back and
/// answers a clean error. The Impl has already refused bad requests.
/// </summary>
codeunit 10076947 "Nonstock Item Create Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        NonstockItem: Record "Nonstock Item";
        Item: Record Item;
        CatalogItemManagement: Codeunit "Catalog Item Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Code[20];
    begin
        RequestJson := Rec.GetRequestJson();
        RequestJson.Get('entryNo', Token);
        EntryNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(EntryNo));
        NonstockItem.Get(EntryNo);
        // Same path as the Create Item action on the Catalog Item Card, without its confirmation message.
        CatalogItemManagement.CreateItemFromNonstock(NonstockItem);
        NonstockItem.Get(EntryNo);
        Item.Get(NonstockItem."Item No.");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', NonstockItem."Entry No.");
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('itemId', Format(Item.SystemId, 0, 4).ToLower());
        ResponseJson.Add('itemTemplateCode', NonstockItem."Item Templ. Code");
        ResponseJson.Add('description', Item.Description);
        ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        ResponseJson.Add('vendorNo', Item."Vendor No.");
        ResponseJson.Add('vendorItemNo', Item."Vendor Item No.");
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
