namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Location;
using Origo.Bifrost;

/// <summary>
/// Inventory.SKU.Get. Reads stockkeeping units with their planning and cost fields. Read-only.
/// </summary>
codeunit 10076996 "SKU Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SKURequest: Codeunit "SKU Request ori";
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        LocationKeyTok: Label 'locationCode', Locked = true;
        VariantKeyTok: Label 'variantCode', Locked = true;
        AllowedKeysTok: Label 'itemNo, locationCode, variantCode', Locked = true;
        MaxRows: Integer;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Availability, Database::"Stockkeeping Unit", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Stockkeeping Unit");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads stockkeeping units with their planning and cost fields.', Comment = 'is-IS=Les birgðageymsluvörur með skipulags- og kostnaðarreitum þeirra.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'stockkeeping unit, sku, location, variant, reorder point, planning', Comment = 'is-IS=birgðageymsluvara, sku, staðsetning, afbrigði, pöntunarmark, áætlun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Read the stockkeeping units of an item, optionally for one location or variant.', Comment = 'is-IS=Lestu birgðageymsluvörur vöru, að vali fyrir eina staðsetningu eða eitt afbrigði.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The units are selected under data.itemNo, data.locationCode and data.variantCode; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'Only the units of this item. Omit it to read the units of every item.'));
        Target.Add(ContractMgt.TargetEntry('data.locationCode', 'location code', 'Only units with this exact location code; an empty text selects the units without a location.'));
        Target.Add(ContractMgt.TargetEntry('data.variantCode', 'variant code', 'Only units with this exact variant code; an empty text selects the units without a variant.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemNoLbl: Label 'Item number, at most 20 characters. Omit it to read the units of every item.', Comment = 'is-IS=Vörunúmer, mest 20 stafir. Slepptu því til að lesa einingar allra vara.';
        LocationLbl: Label 'Exact location code, at most 10 characters. An empty text selects units without a location. Omit it to read every location.', Comment = 'is-IS=Nákvæmur staðsetningarkóði, mest 10 stafir. Tómur texti velur einingar án staðsetningar. Slepptu honum til að lesa allar staðsetningar.';
        VariantLbl: Label 'Exact variant code, at most 10 characters. An empty text selects units without a variant. Omit it to read every variant.', Comment = 'is-IS=Nákvæmur afbrigðiskóði, mest 10 stafir. Tómur texti velur einingar án afbrigðis. Slepptu honum til að lesa öll afbrigði.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, LocationLbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, VariantLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        SkuField: JsonObject;
        Children: JsonArray;
    begin
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number.'));
        Children.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code; empty for a unit per variant only.'));
        Children.Add(ContractMgt.ResponseField('variantCode', 'string', 'Variant code; empty for a unit per location only.'));
        Children.Add(ContractMgt.ResponseField('replenishmentSystem', 'string', 'Replenishment system, invariant member name.'));
        Children.Add(ContractMgt.ResponseField('reorderingPolicy', 'string', 'Reordering policy, invariant member name.'));
        Children.Add(ContractMgt.ResponseField('includeInventory', 'boolean', 'Include inventory in planning.'));
        Children.Add(ContractMgt.ResponseField('reorderPoint', 'decimal', 'Reorder point.'));
        Children.Add(ContractMgt.ResponseField('reorderQuantity', 'decimal', 'Reorder quantity.'));
        Children.Add(ContractMgt.ResponseField('maximumInventory', 'decimal', 'Maximum inventory.'));
        Children.Add(ContractMgt.ResponseField('safetyStockQuantity', 'decimal', 'Safety stock quantity.'));
        Children.Add(ContractMgt.ResponseField('minimumOrderQuantity', 'decimal', 'Minimum order quantity.'));
        Children.Add(ContractMgt.ResponseField('maximumOrderQuantity', 'decimal', 'Maximum order quantity.'));
        Children.Add(ContractMgt.ResponseField('orderMultiple', 'decimal', 'Order multiple.'));
        Children.Add(ContractMgt.ResponseField('lotSize', 'decimal', 'Lot size.'));
        Children.Add(ContractMgt.ResponseField('leadTimeCalculation', 'string', 'Lead time calculation, date formula in invariant form.'));
        Children.Add(ContractMgt.ResponseField('safetyLeadTime', 'string', 'Safety lead time, date formula in invariant form.'));
        Children.Add(ContractMgt.ResponseField('transferFromCode', 'string', 'Transfer-from location code.'));
        Children.Add(ContractMgt.ResponseField('vendorNo', 'string', 'Vendor number.'));
        Children.Add(ContractMgt.ResponseField('vendorItemNo', 'string', 'Vendor item number.'));
        Children.Add(ContractMgt.ResponseField('unitCost', 'decimal', 'Unit cost of the unit.'));
        Children.Add(ContractMgt.ResponseField('standardCost', 'decimal', 'Standard cost of the unit.'));
        Children.Add(ContractMgt.ResponseField('lastDirectCost', 'decimal', 'Last direct cost of the unit.'));
        Children.Add(ContractMgt.ResponseField('inventory', 'decimal', 'Inventory of the unit, calculated for its location and variant.'));
        SkuField := ContractMgt.ResponseField('skus', 'array', 'The matching stockkeeping units, at most 500.');
        SkuField.Add('children', Children);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(SkuField);
        Fields.Add(ContractMgt.ResponseField('count', 'integer', 'Number of units in skus.'));
        Fields.Add(ContractMgt.ResponseField('truncated', 'boolean', 'True when more than 500 units matched and only the first 500 are listed.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send itemNo, locationCode and variantCode as text.', Comment = 'is-IS=Sendu itemNo, locationCode og variantCode sem texta.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are itemNo, locationCode and variantCode.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, locationCode og variantCode.';
        InvalidWhenLbl: Label 'A code is too long, or the Availability domain is turned off.', Comment = 'is-IS=Kóði er of langur, eða framboðssviðið er óvirkt.';
        InvalidFixLbl: Label 'Shorten the code, or turn the Availability domain on from the Inventory Setup page.', Comment = 'is-IS=Styttu kóðann, eða kveiktu á framboðssviðinu á síðunni Uppsetning birgða.';
        PermissionWhenLbl: Label 'The caller cannot read stockkeeping units.', Comment = 'is-IS=Kallandinn getur ekki lesið birgðageymsluvörur.';
        PermissionFixLbl: Label 'Assign a permission set that reads stockkeeping units.', Comment = 'is-IS=Úthlutaðu heimildasafni sem les birgðageymsluvörur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Availability domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read stockkeeping units.');
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Reads stockkeeping units.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        CreateLbl: Label 'Create the stockkeeping units that are missing for an item.', Comment = 'is-IS=Stofna birgðageymsluvörur sem vantar fyrir vöru.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.SKU.Create', CreateLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Read the stockkeeping units of item 1000 at location MAIN', Comment = 'is-IS=Lesa birgðageymsluvörur vöru 1000 á staðsetningu MAIN';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.SKU.Get","data":{"itemNo":"1000","locationCode":"MAIN"}}', '{"status":"Success","count":1,"truncated":false,"skus":[{"itemNo":"1000","locationCode":"MAIN","variantCode":"","reorderPoint":10,"reorderQuantity":50,"unitCost":12.5,"inventory":40}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads stockkeeping units (one per item, location and variant) with their planning and cost fields. Nothing is changed.', Comment = 'is-IS=Les birgðageymsluvörur (eina fyrir hverja vöru, staðsetningu og afbrigði) með skipulags- og kostnaðarreitum. Engu er breytt.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'locationCode and variantCode are exact codes: an empty text selects units without that code, an omitted key does not restrict. At most 500 units are listed, in key order; truncated is true when more matched. Use Inventory.SKU.Create to make missing units.', Comment = 'is-IS=locationCode og variantCode eru nákvæmir kóðar: tómur texti velur einingar án kóðans, lykill sem er sleppt takmarkar ekki. Í mesta lagi 500 einingar eru taldar upp, í lyklaröð; truncated er true þegar fleiri pössuðu. Notaðu Inventory.SKU.Create til að stofna einingar sem vantar.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        StockkeepingUnit: Record "Stockkeeping Unit";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Skus: JsonArray;
        Truncated: Boolean;
    begin
        if not SKURequest.AssertCanRun(Argument, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('locationCode') then;
        if RequestJson.Contains('variantCode') then;
        if not SKURequest.RejectUnknownKeys(Argument, RequestJson, AllowedKeysTok) then
            exit;
        if not SKURequest.CheckText(Argument, RequestJson, ItemNoKeyTok, MaxStrLen(StockkeepingUnit."Item No.")) then
            exit;
        if not SKURequest.CheckText(Argument, RequestJson, LocationKeyTok, MaxStrLen(StockkeepingUnit."Location Code")) then
            exit;
        if not SKURequest.CheckText(Argument, RequestJson, VariantKeyTok, MaxStrLen(StockkeepingUnit."Variant Code")) then
            exit;
        if RequestJson.Contains(ItemNoKeyTok) then
            StockkeepingUnit.SetRange("Item No.", CopyStr(SKURequest.ReadText(RequestJson, ItemNoKeyTok), 1, MaxStrLen(StockkeepingUnit."Item No.")));
        if RequestJson.Contains(LocationKeyTok) then
            StockkeepingUnit.SetRange("Location Code", CopyStr(SKURequest.ReadText(RequestJson, LocationKeyTok), 1, MaxStrLen(StockkeepingUnit."Location Code")));
        if RequestJson.Contains(VariantKeyTok) then
            StockkeepingUnit.SetRange("Variant Code", CopyStr(SKURequest.ReadText(RequestJson, VariantKeyTok), 1, MaxStrLen(StockkeepingUnit."Variant Code")));
        MaxRows := 500;
        if StockkeepingUnit.FindSet() then
            repeat
                if Skus.Count() >= MaxRows then
                    Truncated := true
                else
                    Skus.Add(SKURequest.BuildSkuJson(StockkeepingUnit));
            until Truncated or (StockkeepingUnit.Next() = 0);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('count', Skus.Count());
        ResponseJson.Add('truncated', Truncated);
        ResponseJson.Add('skus', Skus);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
