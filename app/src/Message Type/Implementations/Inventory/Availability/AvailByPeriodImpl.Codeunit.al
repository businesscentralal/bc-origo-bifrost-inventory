namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Foundation.Period;
using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Origo.Bifrost;
using System.Utilities;

/// <summary>
/// Inventory.AvailabilityByPeriod.Get. Reads projected availability the way Item Availability by Periods does.
/// Does not write.
/// </summary>
codeunit 10076857 "Avail. By Period Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        ItemsKeyTok: Label 'items', Locked = true;
        VariantKeyTok: Label 'variant', Locked = true;
        LocationKeyTok: Label 'location', Locked = true;
        PeriodTypeKeyTok: Label 'periodType', Locked = true;
        FromKeyTok: Label 'from', Locked = true;
        PeriodsKeyTok: Label 'periods', Locked = true;
        AmountTypeKeyTok: Label 'amountType', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        DateExpectedTok: Label 'date', Locked = true;
        IntegerExpectedTok: Label 'integer', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;
        NetChangeTok: Label 'netChange', Locked = true;
        BalanceAtDateTok: Label 'balanceAtDate', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Location: Record Location;
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Availability) then
            exit(false);
        exit(Item.ReadPermission() and ItemVariant.ReadPermission() and Location.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads projected item availability by day, week, month, quarter, or year.', Comment = 'is-IS=Les áætlað framboð vöru eftir degi, viku, mánuði, ársfjórðungi eða ári.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'availability, period, gross requirement, projected available balance, inventory', Comment = 'is-IS=framboð, tímabil, heildarþörf, áætlað tiltækt magn, birgðir';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reads projected availability for one or more items across calendar periods.', Comment = 'is-IS=Les áætlað framboð fyrir eina eða fleiri vörur yfir dagatals tímabil.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the items are named in data.itemNo or data.items."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The item whose availability is read. Use items when several items are sent.', Comment = 'is-IS=Varan sem framboð er lesið fyrir. Notaðu items þegar nokkrar vörur eru sendar.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', TargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.items', 'array of item nos.', 'Up to 20 item numbers; use it instead of itemNo, never both.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoLbl: Label 'One item number. Omit it when items is sent.', Comment = 'is-IS=Eitt vörunúmer. Slepptu því þegar items er sent.';
        ItemsLbl: Label 'Up to 20 item numbers. Do not also send itemNo.', Comment = 'is-IS=Allt að 20 vörunúmer. Ekki senda itemNo líka.';
        VariantLbl: Label 'A variant code of the item. Leave it out to include every variant. A variant that does not exist on the item is refused.', Comment = 'is-IS=Afbrigðiskóði vörunnar. Slepptu honum til að taka öll afbrigði með. Afbrigði sem er ekki til á vörunni er hafnað.';
        LocationLbl: Label 'A location code. Leave it out to include every location. A location that does not exist is refused.', Comment = 'is-IS=Staðsetningarkóði. Slepptu honum til að taka allar staðsetningar með. Staðsetningu sem er ekki til er hafnað.';
        PeriodTypeLbl: Label 'day, week, month, quarter, or year.', Comment = 'is-IS=day, week, month, quarter eða year.';
        FromLbl: Label 'A date inside the first calendar period, as YYYY-MM-DD.', Comment = 'is-IS=Dagsetning innan fyrsta dagatals tímabilsins, á forminu YYYY-MM-DD.';
        PeriodsLbl: Label 'How many periods to return, from 1 to 53.', Comment = 'is-IS=Hversu mörg tímabil eiga að koma til baka, frá 1 til 53.';
        AmountTypeLbl: Label 'netChange (default) reads each period on its own. balanceAtDate reads everything up to the period end.', Comment = 'is-IS=netChange (sjálfgefið) les hvert tímabil fyrir sig. balanceAtDate les allt fram að lokum tímabilsins.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('items', 'array', false, ItemsLbl));
        Parameters.Add(ContractMgt.Parameter('variant', 'string', false, VariantLbl));
        Parameters.Add(ContractMgt.Parameter('location', 'string', false, LocationLbl));
        Parameters.Add(ContractMgt.Parameter('periodType', 'string', true, PeriodTypeLbl));
        Parameters.Add(ContractMgt.Parameter('from', 'string', true, FromLbl));
        Parameters.Add(ContractMgt.Parameter('periods', 'integer', true, PeriodsLbl));
        Parameters.Add(ContractMgt.Parameter('amountType', 'string', false, AmountTypeLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        ItemChildren: JsonArray;
        Periods: JsonObject;
        NestedPeriods: JsonObject;
        Items: JsonObject;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number; present when itemNo was sent.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The item description; present when itemNo was sent.'));
        Fields.Add(ContractMgt.ResponseField('variant', 'string', 'The variant code that was sent; empty when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('location', 'string', 'The location code that was sent; empty when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('periodType', 'string', 'day, week, month, quarter or year, in lower case.'));
        Fields.Add(ContractMgt.ResponseField('amountType', 'string', 'netChange or balanceAtDate.'));
        Periods := ContractMgt.ResponseField('periods', 'array', 'One row per period; present when itemNo was sent.');
        Periods.Add('children', PeriodChildren());
        Fields.Add(Periods);
        ItemChildren.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        ItemChildren.Add(ContractMgt.ResponseField('description', 'string', 'The item description.'));
        NestedPeriods := ContractMgt.ResponseField('periods', 'array', 'One row per period.');
        NestedPeriods.Add('children', PeriodChildren());
        ItemChildren.Add(NestedPeriods);
        Items := ContractMgt.ResponseField('items', 'array', 'One entry per item, in the order sent; present when items was sent.');
        Items.Add('children', ItemChildren);
        Fields.Add(Items);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'itemNo is missing and items was not sent, or periodType, from, or periods is missing.', Comment = 'is-IS=itemNo vantar og items var ekki sent, eða periodType, from eða periods vantar.';
        MissingFixLbl: Label 'Send itemNo, or send items with at most 20 item numbers. Also send periodType, from, and periods.', Comment = 'is-IS=Sendu itemNo, eða sendu items með í mesta lagi 20 vörunúmerum. Sendu einnig periodType, from og periods.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send itemNo as text, from as a date, periods as a whole number, and items as an array of item numbers.', Comment = 'is-IS=Sendu itemNo sem texta, from sem dagsetningu, periods sem heila tölu og items sem fylki vörunúmera.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are itemNo, items, variant, location, periodType, from, periods and amountType.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, items, variant, location, periodType, from, periods og amountType.';
        NotFoundWhenLbl: Label 'The item number, variant, or location does not exist.', Comment = 'is-IS=Vörunúmerið, afbrigðið eða staðsetningin er ekki til.';
        NotFoundFixLbl: Label 'Check the item no.', Comment = 'is-IS=Athugaðu vörunúmerið.';
        ConflictWhenLbl: Label 'itemNo and items were both sent.', Comment = 'is-IS=itemNo og items voru bæði send.';
        ConflictFixLbl: Label 'Send either itemNo or items, not both.', Comment = 'is-IS=Sendu annaðhvort itemNo eða items, ekki bæði.';
        PeriodTypeWhenLbl: Label 'periodType is not day, week, month, quarter, or year, or amountType is not netChange or balanceAtDate.', Comment = 'is-IS=periodType er ekki day, week, month, quarter eða year, eða amountType er ekki netChange eða balanceAtDate.';
        PeriodTypeFixLbl: Label 'Use day, week, month, quarter or year. Use netChange or balanceAtDate for amountType.', Comment = 'is-IS=Notaðu day, week, month, quarter eða year. Notaðu netChange eða balanceAtDate fyrir amountType.';
        LimitWhenLbl: Label 'periods is above 53, or more than 20 items were sent.', Comment = 'is-IS=periods er yfir 53, eða fleiri en 20 vörur voru sendar.';
        LimitFixLbl: Label 'Split the call.', Comment = 'is-IS=Skiptu kallinu.';
        StockWhenLbl: Label 'The item is Service or Non-Inventory, so it has no availability.', Comment = 'is-IS=Varan er þjónusta eða ekki birgðavara, svo hún hefur ekkert framboð.';
        StockFixLbl: Label 'Use an inventory item.', Comment = 'is-IS=Notaðu birgðavöru.';
        PermissionWhenLbl: Label 'The caller cannot read items, variants, or locations.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur, afbrigði eða staðsetningar.';
        PermissionFixLbl: Label 'Assign Bifrost Read-Only (extended by Inventory read permissions) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu Bifröst Lesaðgangur (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, PeriodTypeWhenLbl, PeriodTypeFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Availability domain is turned off in Inventory Setup, periods is below 1, or the calendar cannot build every requested period.', 'Turn on the Availability domain, or use a periods value from 1 to 53 and a from date inside the calendar.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, LimitWhenLbl, LimitFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, StockWhenLbl, StockFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Reads projected availability by calendar period for one or more items.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Read-Only');
        Preconditions.Add('The Availability domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read items, item variants and locations.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Item.Availability.Get', 'Use it for the availability of items per location on one delivery date, instead of per calendar period.'));
        Related.Add(ContractMgt.RelatedEntry('Item.Inventory.Get', 'Use it for the physical stock on hand per location, without any projection.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Read two months for one item', Comment = 'is-IS=Lesa tvo mánuði fyrir eina vöru';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.AvailabilityByPeriod.Get","data":{"itemNo":"ITEM","periodType":"month","from":"2026-10-16","periods":2}}', '{"status":"Success","itemNo":"ITEM","description":"Item","variant":"","location":"","periodType":"month","amountType":"netChange","periods":[{"periodStart":"2026-10-01","periodEnd":"2026-10-31","grossRequirement":0,"scheduledReceipt":0,"plannedOrderReceipt":0,"projectedAvailableBalance":0,"inventory":0,"amountType":"netChange"}]}'));
        Examples.Add(ContractMgt.Example(
            'Read one week for items 1000 and 1100 at location BLUE',
            '{"type":"Inventory.AvailabilityByPeriod.Get","data":{"items":["1000","1100"],"location":"BLUE","periodType":"week","from":"2026-10-22","periods":1,"amountType":"balanceAtDate"}}',
            '{"status":"Success","periodType":"week","amountType":"balanceAtDate","variant":"","location":"BLUE","items":[{"itemNo":"1000","description":"Bicycle","periods":[{"periodStart":"2026-10-19","periodEnd":"2026-10-25","grossRequirement":4,"scheduledReceipt":10,"plannedOrderReceipt":0,"projectedAvailableBalance":46,"inventory":40,"amountType":"balanceAtDate"}]},{"itemNo":"1100","description":"Front wheel","periods":[{"periodStart":"2026-10-19","periodEnd":"2026-10-25","grossRequirement":0,"scheduledReceipt":0,"plannedOrderReceipt":0,"projectedAvailableBalance":25,"inventory":25,"amountType":"balanceAtDate"}]}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads projected availability by calendar period: gross requirement, scheduled receipt, planned order receipt, projected available balance, and inventory. It does not change supply or demand.', Comment = 'is-IS=Les áætlað framboð eftir dagatals tímabili: heildarþörf, áætlaða móttöku, áætlaða pöntunarmóttöku, áætlað tiltækt magn og birgðir. Hún breytir hvorki framboði né eftirspurn.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'The first period is the calendar period that contains from. With amountType netChange (the default) the amounts cover that period only; with balanceAtDate they cover everything up to the period end. Projected available balance is the balance at the period end in both modes. Inventory is the item ledger quantity within the same dates: the net change of the period with netChange, and the on-hand quantity at the period end with balanceAtDate. One item (itemNo) is answered at the top level; several items (items) are answered in items, each with its own periods. variant and location are exact codes, not filter expressions, and drop shipments are always left out. A service or non-inventory item is refused. At most 53 periods and 20 items are returned. The type only reads, so it can be repeated freely.', Comment = 'is-IS=Fyrsta tímabilið er dagatals tímabilið sem inniheldur from. Með amountType netChange (sjálfgefið) ná upphæðir aðeins yfir tímabilið; með balanceAtDate ná þær yfir allt fram að lokum tímabilsins. Áætlað tiltækt magn er staðan í lok tímabilsins í báðum stillingum. Birgðir (inventory) eru vörufærslumagn innan sömu dagsetninga: nettóbreyting tímabilsins með netChange og magn á hendi í lok tímabilsins með balanceAtDate. Ein vara (itemNo) er svarað á efsta stigi; fleiri vörur (items) eru svaraðar í items, hver með sín tímabil. variant og location eru nákvæmir kóðar, ekki síutjáningar, og beinar sendingar eru alltaf undanskildar. Þjónustuvöru eða vöru sem er ekki birgðavara er hafnað. Í mesta lagi 53 tímabil og 20 vörur koma til baka. Gerðin les aðeins og því má endurtaka kallið að vild.';
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNos: List of [Text];
        PeriodType: Enum "Analysis Period Type";
        FromDate: Date;
        PeriodCount: Integer;
        VariantCode: Text;
        LocationCode: Text;
        HasItems: Boolean;
        BalanceAtDate: Boolean;
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('items') then;
        if RequestJson.Contains('variant') then;
        if RequestJson.Contains('location') then;
        if RequestJson.Contains('periodType') then;
        if RequestJson.Contains('from') then;
        if RequestJson.Contains('periods') then;
        if RequestJson.Contains('amountType') then;
        if not ReadCommon(Argument, RequestJson, HasItems, ItemNos, VariantCode, LocationCode, PeriodType, FromDate, PeriodCount) then
            exit;
        if not ReadAmountType(Argument, RequestJson, BalanceAtDate) then
            exit;
        if HasItems then begin
            if not BuildItems(Argument, ItemNos, VariantCode, LocationCode, PeriodType, FromDate, PeriodCount, BalanceAtDate, ResponseJson) then
                exit;
        end else
            if not BuildOne(Argument, ItemNos.Get(1), VariantCode, LocationCode, PeriodType, FromDate, PeriodCount, BalanceAtDate, ResponseJson, false) then
                exit;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Location: Record Location;
        DomainDisabledErr: Label 'The Availability domain is turned off for this company.', Comment = 'is-IS=Framboðssviðið er slökkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Ask an administrator with the Inv. Posting Gate permission set to turn the domain on from the Inventory Setup page. Data.Records.Set cannot change this setup.', Comment = 'is-IS=Biðjið kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á sviðinu á síðunni Uppsetning birgða. Data.Records.Set getur ekki breytt þessari uppsetningu.';
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign BIFROST Read ori (extended by BIFROST InvRead ori) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Read ori (með viðbótinni BIFROST InvRead ori) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        if not InventorySetup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Availability) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        if Item.ReadPermission() and ItemVariant.ReadPermission() and Location.ReadPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo, items, variant, location, periodType, from, periods and amountType.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, items, variant, location, periodType, from, periods og amountType.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ItemNoKeyTok, ItemsKeyTok, VariantKeyTok, LocationKeyTok, PeriodTypeKeyTok, FromKeyTok, PeriodsKeyTok, AmountTypeKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, KeyName, KeyName, '', UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadCommon(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var HasItems: Boolean; var ItemNos: List of [Text]; var VariantCode: Text; var LocationCode: Text; var PeriodType: Enum "Analysis Period Type"; var FromDate: Date; var PeriodCount: Integer): Boolean
    var
        ItemNo: Text;
        PeriodTypeText: Text;
        FromText: Text;
    begin
        Clear(ItemNos);
        HasItems := RequestJson.Contains(ItemsKeyTok);
        if HasItems and RequestJson.Contains(ItemNoKeyTok) then begin
            RespondConflict(Argument);
            exit(false);
        end;
        if HasItems then begin
            if not ReadItemNos(Argument, RequestJson, ItemNos) then
                exit(false);
        end else begin
            if not ReadText(Argument, RequestJson, ItemNoKeyTok, true, ItemNo) then
                exit(false);
            ItemNos.Add(ItemNo);
        end;
        if not ReadText(Argument, RequestJson, VariantKeyTok, false, VariantCode) then
            exit(false);
        if not ReadText(Argument, RequestJson, LocationKeyTok, false, LocationCode) then
            exit(false);
        if not ReadText(Argument, RequestJson, PeriodTypeKeyTok, true, PeriodTypeText) then
            exit(false);
        if not ParsePeriodType(Argument, PeriodTypeText, PeriodType) then
            exit(false);
        if not ReadDate(Argument, RequestJson, FromKeyTok, true, FromText, FromDate) then
            exit(false);
        if not ReadInteger(Argument, RequestJson, PeriodsKeyTok, true, PeriodCount) then
            exit(false);
        exit(ValidatePeriodCount(Argument, PeriodCount));
    end;

    local procedure ReadItemNos(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemNos: List of [Text]): Boolean
    var
        Token: JsonToken;
        EntryToken: JsonToken;
        ItemNo: Text;
        Raw: Text;
    begin
        if not RequestJson.Get(ItemsKeyTok, Token) then begin
            RespondMissing(Argument, ItemsKeyTok);
            exit(false);
        end;
        if not Token.IsArray() then begin
            RespondFormat(Argument, ItemsKeyTok, '', ArrayExpectedTok);
            exit(false);
        end;
        if Token.AsArray().Count() = 0 then begin
            RespondMissing(Argument, ItemsKeyTok);
            exit(false);
        end;
        if Token.AsArray().Count() > 20 then begin
            RespondLimit(Argument, ItemsKeyTok, Format(Token.AsArray().Count()));
            exit(false);
        end;
        foreach EntryToken in Token.AsArray() do begin
            if not EntryToken.IsValue() then begin
                RespondFormat(Argument, ItemsKeyTok, '', TextExpectedTok);
                exit(false);
            end;
            EntryToken.WriteTo(Raw);
            if not Raw.StartsWith('"') then begin
                RespondFormat(Argument, ItemsKeyTok, Raw, TextExpectedTok);
                exit(false);
            end;
            ItemNo := EntryToken.AsValue().AsText();
            if ItemNo = '' then begin
                RespondMissing(Argument, ItemNoKeyTok);
                exit(false);
            end;
            ItemNos.Add(ItemNo);
        end;
        exit(true);
    end;

    local procedure BuildItems(var Argument: Record "Message Argument ori"; ItemNos: List of [Text]; VariantCode: Text; LocationCode: Text; PeriodType: Enum "Analysis Period Type"; FromDate: Date; PeriodCount: Integer; BalanceAtDate: Boolean; var ResponseJson: JsonObject): Boolean
    var
        Items: JsonArray;
        ItemJson: JsonObject;
        ItemNo: Text;
    begin
        foreach ItemNo in ItemNos do begin
            Clear(ItemJson);
            if not BuildOne(Argument, ItemNo, VariantCode, LocationCode, PeriodType, FromDate, PeriodCount, BalanceAtDate, ItemJson, true) then
                exit(false);
            Items.Add(ItemJson);
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('periodType', PeriodTypeName(PeriodType));
        ResponseJson.Add('amountType', AmountTypeName(BalanceAtDate));
        ResponseJson.Add('variant', VariantCode);
        ResponseJson.Add('location', LocationCode);
        ResponseJson.Add('items', Items);
        exit(true);
    end;

    local procedure BuildOne(var Argument: Record "Message Argument ori"; ItemNo: Text; VariantCode: Text; LocationCode: Text; PeriodType: Enum "Analysis Period Type"; FromDate: Date; PeriodCount: Integer; BalanceAtDate: Boolean; var ResponseJson: JsonObject; Nested: Boolean): Boolean
    var
        Item: Record Item;
        Periods: JsonArray;
        Description: Text;
        ItemNoText: Code[20];
    begin
        if not LoadItem(Argument, ItemNo, VariantCode, LocationCode, Item) then
            exit(false);
        Description := Item.Description;
        ItemNoText := Item."No.";
        if not BuildPeriods(Argument, Item, PeriodType, FromDate, PeriodCount, BalanceAtDate, Periods) then
            exit(false);
        if Nested then begin
            ResponseJson.Add('itemNo', ItemNoText);
            ResponseJson.Add('description', Description);
            ResponseJson.Add('periods', Periods);
            exit(true);
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNoText);
        ResponseJson.Add('description', Description);
        ResponseJson.Add('variant', VariantCode);
        ResponseJson.Add('location', LocationCode);
        ResponseJson.Add('periodType', PeriodTypeName(PeriodType));
        ResponseJson.Add('amountType', AmountTypeName(BalanceAtDate));
        ResponseJson.Add('periods', Periods);
        exit(true);
    end;

    local procedure LoadItem(var Argument: Record "Message Argument ori"; ItemNo: Text; VariantCode: Text; LocationCode: Text; var Item: Record Item): Boolean
    var
        ItemVariant: Record "Item Variant";
        Location: Record Location;
    begin
        if StrLen(ItemNo) > MaxStrLen(Item."No.") then begin
            RespondItemNotFound(Argument, ItemNo);
            exit(false);
        end;
        if not Item.Get(CopyStr(ItemNo, 1, MaxStrLen(Item."No."))) then begin
            RespondItemNotFound(Argument, ItemNo);
            exit(false);
        end;
        if Item.Type in [Item.Type::Service, Item.Type::"Non-Inventory"] then begin
            RespondNonStock(Argument, Item."No.");
            exit(false);
        end;
        if VariantCode <> '' then begin
            if StrLen(VariantCode) > MaxStrLen(ItemVariant.Code) then begin
                RespondVariantNotFound(Argument, VariantCode);
                exit(false);
            end;
            ItemVariant.SetLoadFields(Code);
            ItemVariant.SetRange("Item No.", Item."No.");
            ItemVariant.SetRange(Code, CopyStr(VariantCode, 1, MaxStrLen(ItemVariant.Code)));
            if ItemVariant.IsEmpty() then begin
                RespondVariantNotFound(Argument, VariantCode);
                exit(false);
            end;
            Item.SetRange("Variant Filter", CopyStr(VariantCode, 1, MaxStrLen(Item."Variant Filter")));
        end;
        if LocationCode <> '' then begin
            if StrLen(LocationCode) > MaxStrLen(Location.Code) then begin
                RespondLocationNotFound(Argument, LocationCode);
                exit(false);
            end;
            Location.SetLoadFields(Code);
            if not Location.Get(CopyStr(LocationCode, 1, MaxStrLen(Location.Code))) then begin
                RespondLocationNotFound(Argument, LocationCode);
                exit(false);
            end;
            Item.SetRange("Location Filter", Location.Code);
        end;
        Item.SetRange("Drop Shipment Filter", false);
        exit(true);
    end;

    local procedure BuildPeriods(var Argument: Record "Message Argument ori"; var Item: Record Item; PeriodType: Enum "Analysis Period Type"; FromDate: Date; PeriodCount: Integer; BalanceAtDate: Boolean; var Periods: JsonArray): Boolean
    var
        Calendar: Record Date;
        PeriodPageMgt: Codeunit PeriodPageManagement;
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        PeriodJson: JsonObject;
        GrossRequirement: Decimal;
        PlannedOrderReceipt: Decimal;
        ScheduledReceipt: Decimal;
        PlannedOrderReleases: Decimal;
        ProjectedAvailableBalance: Decimal;
        ExpectedInventory: Decimal;
        QtyAvailable: Decimal;
        AvailableInventory: Decimal;
        PeriodIndex: Integer;
    begin
        Calendar."Period Start" := FromDate;
        if not PeriodPageMgt.FindDate('=<>', Calendar, PeriodType) then begin
            RespondPeriodBounds(Argument, FromDate);
            exit(false);
        end;
        for PeriodIndex := 1 to PeriodCount do begin
            if BalanceAtDate then
                Item.SetRange("Date Filter", 0D, Calendar."Period End")
            else
                Item.SetRange("Date Filter", Calendar."Period Start", Calendar."Period End");
            ItemAvailFormsMgt.CalcAvailQuantities(
                Item,
                BalanceAtDate,
                GrossRequirement,
                PlannedOrderReceipt,
                ScheduledReceipt,
                PlannedOrderReleases,
                ProjectedAvailableBalance,
                ExpectedInventory,
                QtyAvailable,
                AvailableInventory);
            Clear(PeriodJson);
            PeriodJson.Add('periodStart', Format(Calendar."Period Start", 0, 9));
            PeriodJson.Add('periodEnd', Format(NormalDate(Calendar."Period End"), 0, 9));
            PeriodJson.Add('grossRequirement', GrossRequirement);
            PeriodJson.Add('scheduledReceipt', ScheduledReceipt);
            PeriodJson.Add('plannedOrderReceipt', PlannedOrderReceipt);
            PeriodJson.Add('projectedAvailableBalance', ProjectedAvailableBalance);
            PeriodJson.Add('inventory', Item.Inventory);
            PeriodJson.Add('amountType', AmountTypeName(BalanceAtDate));
            Periods.Add(PeriodJson);
            if PeriodIndex = PeriodCount then
                exit(true);
            if PeriodPageMgt.NextDate(1, Calendar, PeriodType) = 0 then begin
                RespondPeriodBounds(Argument, Calendar."Period Start");
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ParsePeriodType(var Argument: Record "Message Argument ori"; PeriodTypeText: Text; var PeriodType: Enum "Analysis Period Type"): Boolean
    begin
        case LowerCase(PeriodTypeText) of
            'day':
                PeriodType := PeriodType::Day;
            'week':
                PeriodType := PeriodType::Week;
            'month':
                PeriodType := PeriodType::Month;
            'quarter':
                PeriodType := PeriodType::Quarter;
            'year':
                PeriodType := PeriodType::Year;
            else begin
                RespondPeriodType(Argument, PeriodTypeText);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ValidatePeriodCount(var Argument: Record "Message Argument ori"; PeriodCount: Integer): Boolean
    var
        CountErr: Label 'periods must be from 1 to 53.', Comment = 'is-IS=periods verður að vera frá 1 til 53.';
        CountNextStepLbl: Label 'Use a periods count from 1 to 53.', Comment = 'is-IS=Notaðu periods frá 1 til 53.';
    begin
        if PeriodCount > 53 then begin
            RespondLimit(Argument, PeriodsKeyTok, Format(PeriodCount));
            exit(false);
        end;
        if PeriodCount < 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, CountErr, PeriodsKeyTok, Format(PeriodCount), '1..53', CountNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadAmountType(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var BalanceAtDate: Boolean): Boolean
    var
        AmountTypeText: Text;
        AmountTypeErr: Label 'amountType is not a supported amount type.', Comment = 'is-IS=amountType er ekki studd tegund upphæðar.';
        AmountTypeNextStepLbl: Label 'Use netChange or balanceAtDate for amountType.', Comment = 'is-IS=Notaðu netChange eða balanceAtDate fyrir amountType.';
    begin
        BalanceAtDate := false;
        if not ReadText(Argument, RequestJson, AmountTypeKeyTok, false, AmountTypeText) then
            exit(false);
        if (AmountTypeText = '') or (LowerCase(AmountTypeText) = LowerCase(NetChangeTok)) then
            exit(true);
        if LowerCase(AmountTypeText) = LowerCase(BalanceAtDateTok) then begin
            BalanceAtDate := true;
            exit(true);
        end;
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, AmountTypeErr, AmountTypeKeyTok, CopyStr(AmountTypeText, 1, 250), 'netChange|balanceAtDate', AmountTypeNextStepLbl);
        exit(false);
    end;

    local procedure AmountTypeName(BalanceAtDate: Boolean): Text
    begin
        if BalanceAtDate then
            exit(BalanceAtDateTok);
        exit(NetChangeTok);
    end;

    local procedure PeriodTypeName(PeriodType: Enum "Analysis Period Type"): Text
    begin
        case PeriodType of
            PeriodType::Day:
                exit('day');
            PeriodType::Week:
                exit('week');
            PeriodType::Month:
                exit('month');
            PeriodType::Quarter:
                exit('quarter');
            PeriodType::Year:
                exit('year');
        end;
        exit('');
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if IsNullToken(Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', TextExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, KeyName, Raw, TextExpectedTok);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value = '') then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var DateText: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        DateText := '';
        Value := 0D;
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if IsNullToken(Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', DateExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, KeyName, Raw, DateExpectedTok);
            exit(false);
        end;
        DateText := Token.AsValue().AsText();
        if not Evaluate(Value, DateText, 9) then begin
            RespondFormat(Argument, KeyName, DateText, DateExpectedTok);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var Value: Integer): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := 0;
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if IsNullToken(Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', IntegerExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or Raw.Contains('.') then begin
            RespondFormat(Argument, KeyName, Raw, IntegerExpectedTok);
            exit(false);
        end;
        if not Evaluate(Value, Raw) then begin
            RespondFormat(Argument, KeyName, Raw, IntegerExpectedTok);
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsNullToken(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori"; KeyName: Text)
    var
        MissingErr: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextStepLbl: Label 'Send itemNo, or send items with at most 20 item numbers. Also send periodType, from, and periods.', Comment = 'is-IS=Sendu itemNo, eða sendu items með í mesta lagi 20 vörunúmerum. Sendu einnig periodType, from og periods.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', KeyName, MissingNextStepLbl);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text; Expected: Text)
    var
        FormatErr: Label 'The value has the wrong format.', Comment = 'is-IS=Gildið er á röngu sniði.';
        FormatNextStepLbl: Label 'Send itemNo as text, from as a date, periods as a whole number, and items as an array of item numbers.', Comment = 'is-IS=Sendu itemNo sem texta, from sem dagsetningu, periods sem heila tölu og items sem fylki vörunúmera.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Received, 1, 250), Expected, FormatNextStepLbl);
    end;

    local procedure RespondConflict(var Argument: Record "Message Argument ori")
    var
        ConflictErr: Label 'itemNo and items cannot both be sent.', Comment = 'is-IS=Ekki er hægt að senda bæði itemNo og items.';
        ConflictNextStepLbl: Label 'Send either itemNo or items, not both.', Comment = 'is-IS=Sendu annaðhvort itemNo eða items, ekki bæði.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, ItemNoKeyTok, '', ItemsKeyTok, ConflictNextStepLbl);
    end;

    local procedure RespondPeriodType(var Argument: Record "Message Argument ori"; Received: Text)
    var
        PeriodTypeErr: Label 'periodType is not a supported period.', Comment = 'is-IS=periodType er ekki stutt tímabil.';
        PeriodTypeNextStepLbl: Label 'Use day, week, month, quarter or year.', Comment = 'is-IS=Notaðu day, week, month, quarter eða year.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, PeriodTypeErr, PeriodTypeKeyTok, CopyStr(Received, 1, 250), 'day|week|month|quarter|year', PeriodTypeNextStepLbl);
    end;

    local procedure RespondLimit(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text)
    var
        LimitErr: Label 'The request is above the limit for one call.', Comment = 'is-IS=Beiðnin er yfir hámarki eins kalls.';
        LimitNextStepLbl: Label 'Split the call.', Comment = 'is-IS=Skiptu kallinu.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, LimitErr, KeyName, CopyStr(Received, 1, 250), '', LimitNextStepLbl);
    end;

    local procedure RespondItemNotFound(var Argument: Record "Message Argument ori"; ItemNo: Text)
    var
        NotFoundErr: Label 'The item does not exist.', Comment = 'is-IS=Varan er ekki til.';
        NotFoundNextStepLbl: Label 'Check the item no.', Comment = 'is-IS=Athugaðu vörunúmerið.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, ItemNoKeyTok, CopyStr(ItemNo, 1, 250), '', NotFoundNextStepLbl);
    end;

    local procedure RespondVariantNotFound(var Argument: Record "Message Argument ori"; VariantCode: Text)
    var
        NotFoundErr: Label 'The variant does not exist on the item.', Comment = 'is-IS=Afbrigðið er ekki til á vörunni.';
        NotFoundNextStepLbl: Label 'Check the variant code.', Comment = 'is-IS=Athugaðu afbrigðiskóðann.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, VariantKeyTok, CopyStr(VariantCode, 1, 250), '', NotFoundNextStepLbl);
    end;

    local procedure RespondLocationNotFound(var Argument: Record "Message Argument ori"; LocationCode: Text)
    var
        NotFoundErr: Label 'The location does not exist.', Comment = 'is-IS=Staðsetningin er ekki til.';
        NotFoundNextStepLbl: Label 'Check the location code.', Comment = 'is-IS=Athugaðu staðsetningarkóðann.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, LocationKeyTok, CopyStr(LocationCode, 1, 250), '', NotFoundNextStepLbl);
    end;

    local procedure RespondPeriodBounds(var Argument: Record "Message Argument ori"; FromDate: Date)
    var
        BoundsErr: Label 'The calendar could not build every requested period.', Comment = 'is-IS=Dagatalið gat ekki byggt öll umbeðin tímabil.';
        BoundsNextStepLbl: Label 'Use a from date inside a supported calendar period and at most 53 periods.', Comment = 'is-IS=Notaðu from innan studds dagatals tímabils og í mesta lagi 53 tímabil.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, BoundsErr, FromKeyTok, Format(FromDate, 0, 9), '1..53', BoundsNextStepLbl);
    end;

    local procedure RespondNonStock(var Argument: Record "Message Argument ori"; ItemNo: Text)
    var
        StockErr: Label 'Service and non-inventory items have no availability.', Comment = 'is-IS=Þjónustuvörur og vörur sem eru ekki birgðavörur hafa ekkert framboð.';
        StockNextStepLbl: Label 'Use an inventory item.', Comment = 'is-IS=Notaðu birgðavöru.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StockErr, ItemNoKeyTok, CopyStr(ItemNo, 1, 250), 'Inventory', StockNextStepLbl);
    end;

    local procedure PeriodChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('periodStart', 'string', 'The first date of the period, as YYYY-MM-DD.'));
        Children.Add(ContractMgt.ResponseField('periodEnd', 'string', 'The last date of the period, as YYYY-MM-DD.'));
        Children.Add(ContractMgt.ResponseField('grossRequirement', 'decimal', 'The quantity required in the period, for example on sales orders and components.'));
        Children.Add(ContractMgt.ResponseField('scheduledReceipt', 'decimal', 'The quantity scheduled to arrive in the period, for example on purchase orders.'));
        Children.Add(ContractMgt.ResponseField('plannedOrderReceipt', 'decimal', 'The quantity planned to arrive in the period on planned orders.'));
        Children.Add(ContractMgt.ResponseField('projectedAvailableBalance', 'decimal', 'The projected available balance at the end of the period.'));
        Children.Add(ContractMgt.ResponseField('inventory', 'decimal', 'The item ledger quantity within the dates of the period: the net change with netChange, the on-hand quantity at the period end with balanceAtDate.'));
        Children.Add(ContractMgt.ResponseField('amountType', 'string', 'netChange or balanceAtDate.'));
    end;
}
