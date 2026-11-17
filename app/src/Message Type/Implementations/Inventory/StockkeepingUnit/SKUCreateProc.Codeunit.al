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
        TempExistingSKU: Record "Stockkeeping Unit" temporary;
        CreateSKUReport: Report "Create Stockkeeping Unit";
        SKURequest: Codeunit "SKU Request ori";
        SKUCreationMethod: Enum "SKU Creation Method";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemsMatched: Integer;
        After: Integer;
        ReplaceExisting: Boolean;
    begin
        RequestJson := Rec.GetRequestJson();
        ReplaceExisting := SKURequest.ReadBoolean(RequestJson, 'replaceExisting', false);
        if RequestJson.Contains('createPer') then
            SKURequest.TryParseCreationMethod(SKURequest.ReadText(RequestJson, 'createPer'), SKUCreationMethod);
        ApplyItemFilters(Item, RequestJson);
        ItemsMatched := Item.Count();
        SnapshotSkuKeys(Item, TempExistingSKU);
        CreateSKUReport.SetParameters(SKUCreationMethod, SKURequest.ReadBoolean(RequestJson, 'itemInInventoryOnly', true), ReplaceExisting);
        CreateSKUReport.UseRequestPage(false);
        CreateSKUReport.SetTableView(Item);
        CreateSKUReport.RunModal();
        After := CountSkus(Item);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemsMatched', ItemsMatched);
        ResponseJson.Add('created', CountNewSkuKeys(Item, TempExistingSKU));
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

    local procedure SnapshotSkuKeys(var Item: Record Item; var TempExistingSKU: Record "Stockkeeping Unit" temporary)
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        StockkeepingUnit.ReadIsolation := IsolationLevel::RepeatableRead;
        StockkeepingUnit.SetLoadFields("Location Code", "Item No.", "Variant Code");
        StockkeepingUnit.SetFilter("Item No.", Item.GetFilter("No."));
        if StockkeepingUnit.FindSet() then
            repeat
                TempExistingSKU.Init();
                TempExistingSKU."Location Code" := StockkeepingUnit."Location Code";
                TempExistingSKU."Item No." := StockkeepingUnit."Item No.";
                TempExistingSKU."Variant Code" := StockkeepingUnit."Variant Code";
                TempExistingSKU.Insert();
            until StockkeepingUnit.Next() = 0;
    end;

    local procedure CountNewSkuKeys(var Item: Record Item; var TempExistingSKU: Record "Stockkeeping Unit" temporary) Created: Integer
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
    begin
        StockkeepingUnit.ReadIsolation := IsolationLevel::ReadCommitted;
        StockkeepingUnit.SetLoadFields("Location Code", "Item No.", "Variant Code");
        StockkeepingUnit.SetFilter("Item No.", Item.GetFilter("No."));
        if StockkeepingUnit.FindSet() then
            repeat
                if not TempExistingSKU.Get(StockkeepingUnit."Location Code", StockkeepingUnit."Item No.", StockkeepingUnit."Variant Code") then
                    Created += 1;
            until StockkeepingUnit.Next() = 0;
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
