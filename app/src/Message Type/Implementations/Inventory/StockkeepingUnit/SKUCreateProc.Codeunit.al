namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.SKU.Create, run through Codeunit.Run so a failure rolls back and answers a clean error.
/// The Impl has already refused bad requests.
/// </summary>
codeunit 10076997 "SKU Create Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Item: Record Item;
        CreateSKUReport: Report "Create Stockkeeping Unit";
        SKURequest: Codeunit "SKU Request ori";
        SKUCreationMethod: Enum "SKU Creation Method";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemsMatched: Integer;
        Before: Integer;
        After: Integer;
        ReplaceExisting: Boolean;
    begin
        RequestJson := Rec.GetRequestJson();
        ReplaceExisting := SKURequest.ReadBoolean(RequestJson, 'replaceExisting', false);
        if RequestJson.Contains('createPer') then
            SKURequest.TryParseCreationMethod(SKURequest.ReadText(RequestJson, 'createPer'), SKUCreationMethod);
        ApplyItemFilters(Item, RequestJson);
        ItemsMatched := Item.Count();
        Before := CountSkus(Item);
        CreateSKUReport.SetParameters(SKUCreationMethod, SKURequest.ReadBoolean(RequestJson, 'itemInInventoryOnly', true), ReplaceExisting);
        CreateSKUReport.UseRequestPage(false);
        CreateSKUReport.SetTableView(Item);
        CreateSKUReport.RunModal();
        After := CountSkus(Item);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemsMatched', ItemsMatched);
        ResponseJson.Add('created', After - Before);
        ResponseJson.Add('skuCount', After);
        ResponseJson.Add('replaceExisting', ReplaceExisting);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>Applies itemFilter, locationFilter and variantFilter to the item; a filter the platform refuses fails the call.</summary>
    procedure ApplyItemFilters(var Item: Record Item; RequestJson: JsonObject)
    var
        SKURequest: Codeunit "SKU Request ori";
        FilterText: Text;
    begin
        Item.Reset();
        Item.SetFilter("No.", SKURequest.ReadText(RequestJson, 'itemFilter'));
        FilterText := SKURequest.ReadText(RequestJson, 'locationFilter');
        if FilterText <> '' then
            Item.SetFilter("Location Filter", FilterText);
        FilterText := SKURequest.ReadText(RequestJson, 'variantFilter');
        if FilterText <> '' then
            Item.SetFilter("Variant Filter", FilterText);
    end;

    /// <summary>Same as ApplyItemFilters but reports a bad filter instead of failing.</summary>
    [TryFunction]
    procedure TryApplyItemFilters(var Item: Record Item; RequestJson: JsonObject)
    begin
        ApplyItemFilters(Item, RequestJson);
    end;

    local procedure CountSkus(var Item: Record Item) Total: Integer
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        ItemNoFilter: Text;
    begin
        ItemNoFilter := Item.GetFilter("No.");
        StockkeepingUnit.SetFilter("Item No.", ItemNoFilter);
        Total := StockkeepingUnit.Count();
    end;
}
