namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Company;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Requisition;
using Origo.Bifrost;

/// <summary>
/// Inventory.AvailableToPromise.Get. Answers when a quantity of an item can be promised, the way Order Promising does
/// (codeunit 5790 Available to Promise, optionally codeunit 99000886 Capable to Promise). Keeps nothing.
/// </summary>
codeunit 10077000 "Avail. To Promise Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        VariantKeyTok: Label 'variant', Locked = true;
        LocationKeyTok: Label 'location', Locked = true;
        QuantityKeyTok: Label 'quantity', Locked = true;
        RequestedDateKeyTok: Label 'requestedDate', Locked = true;
        CapableKeyTok: Label 'capableToPromise', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        DateExpectedTok: Label 'date', Locked = true;
        DecimalExpectedTok: Label 'decimal', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;
        AvailableBasisTok: Label 'availableToPromise', Locked = true;
        CapableBasisTok: Label 'capableToPromise', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Availability) then
            exit(false);
        exit(CanReadSources());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Answers the earliest date a quantity of an item can be promised and the quantity available on the requested date.', Comment = 'is-IS=Svarar fyrstu dagsetningu sem hægt er að lofa magni af vöru og magninu sem er tiltækt á umbeðinni dagsetningu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'available to promise, capable to promise, order promising, delivery date, availability', Comment = 'is-IS=tiltækt til loforðs, hægt að lofa, pöntunarloforð, afhendingardagur, framboð';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Answers when a quantity of one item can be promised, like the Order Promising page.', Comment = 'is-IS=Svarar hvenær hægt er að lofa magni af einni vöru, eins og síðan Pöntunarloforð.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the item is named in data.itemNo."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The item whose quantity is promised.', Comment = 'is-IS=Varan sem magni er lofað af.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoLbl: Label 'The item number. Service and non-inventory items are refused.', Comment = 'is-IS=Vörunúmerið. Þjónustuvörum og vörum sem eru ekki birgðavörur er hafnað.';
        VariantLbl: Label 'A variant code of the item. Leave it out to include every variant. A variant that does not exist on the item is refused.', Comment = 'is-IS=Afbrigðiskóði vörunnar. Slepptu honum til að taka öll afbrigði með. Afbrigði sem er ekki til á vörunni er hafnað.';
        LocationLbl: Label 'A location code. Leave it out to include every location. A location that does not exist is refused.', Comment = 'is-IS=Staðsetningarkóði. Slepptu honum til að taka allar staðsetningar með. Staðsetningu sem er ekki til er hafnað.';
        QuantityLbl: Label 'The quantity to promise, in the base unit of measure of the item. It must be above 0.', Comment = 'is-IS=Magnið sem á að lofa, í grunnmælieiningu vörunnar. Það verður að vera yfir 0.';
        RequestedDateLbl: Label 'The date the quantity is wanted, as YYYY-MM-DD.', Comment = 'is-IS=Dagsetningin sem magnið er óskað, á forminu YYYY-MM-DD.';
        CapableLbl: Label 'true also runs capable to promise, which looks at what could be supplied by new purchase, transfer or production. Off (false) by default.', Comment = 'is-IS=true keyrir einnig hægt að lofa, sem skoðar hvað mætti útvega með nýjum innkaupum, flutningi eða framleiðslu. Slökkt (false) sjálfgefið.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('variant', 'string', false, VariantLbl));
        Parameters.Add(ContractMgt.Parameter('location', 'string', false, LocationLbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'decimal', true, QuantityLbl));
        Parameters.Add(ContractMgt.Parameter('requestedDate', 'string', true, RequestedDateLbl));
        Parameters.Add(ContractMgt.Parameter('capableToPromise', 'boolean', false, CapableLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The item description.'));
        Fields.Add(ContractMgt.ResponseField('variant', 'string', 'The variant code that was sent; empty when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('location', 'string', 'The location code that was sent; empty when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure of the item; quantities are in this unit.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity that was sent.'));
        Fields.Add(ContractMgt.ResponseField('requestedDate', 'string', 'The requested date, as YYYY-MM-DD.'));
        Fields.Add(ContractMgt.ResponseField('availableOnRequestedDate', 'decimal', 'The projected quantity on the requested date, without receipts that come later.'));
        Fields.Add(ContractMgt.ResponseField('canPromiseOnRequestedDate', 'boolean', 'true when earliestDate is the requested date.'));
        Fields.Add(ContractMgt.ResponseField('earliestDate', 'string', 'The earliest date on or after the requested date that the whole quantity can be promised, as YYYY-MM-DD; empty when no date is found.'));
        Fields.Add(ContractMgt.ResponseField('basis', 'string', 'availableToPromise or capableToPromise: which calculation found earliestDate; empty when no date is found.'));
        Fields.Add(ContractMgt.ResponseField('availableToPromiseDate', 'string', 'The earliest date from available to promise only, as YYYY-MM-DD; empty when none is found.'));
        Fields.Add(ContractMgt.ResponseField('capableToPromise', 'boolean', 'true when capable to promise was run.'));
        Fields.Add(ContractMgt.ResponseField('capableToPromiseDate', 'string', 'The date from capable to promise, as YYYY-MM-DD; empty when it was not run or found no date.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'itemNo, quantity or requestedDate is missing or empty.', Comment = 'is-IS=itemNo, quantity eða requestedDate vantar eða er tómt.';
        MissingFixLbl: Label 'Send itemNo, quantity and requestedDate.', Comment = 'is-IS=Sendu itemNo, quantity og requestedDate.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, or requestedDate is not a date.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, eða requestedDate er ekki dagsetning.';
        FormatFixLbl: Label 'Send itemNo, variant and location as text, quantity as a number, requestedDate as YYYY-MM-DD and capableToPromise as true or false.', Comment = 'is-IS=Sendu itemNo, variant og location sem texta, quantity sem tölu, requestedDate sem YYYY-MM-DD og capableToPromise sem true eða false.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are itemNo, variant, location, quantity, requestedDate and capableToPromise.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, variant, location, quantity, requestedDate og capableToPromise.';
        NotFoundWhenLbl: Label 'The item number, variant, or location does not exist.', Comment = 'is-IS=Vörunúmerið, afbrigðið eða staðsetningin er ekki til.';
        NotFoundFixLbl: Label 'Check the item no., variant code and location code.', Comment = 'is-IS=Athugaðu vörunúmerið, afbrigðiskóðann og staðsetningarkóðann.';
        QuantityWhenLbl: Label 'quantity is 0 or below, or the Availability domain is turned off in Inventory Setup.', Comment = 'is-IS=quantity er 0 eða lægra, eða slökkt er á framboðssviðinu í Uppsetningu birgða.';
        QuantityFixLbl: Label 'Send a quantity above 0, or turn on the Availability domain.', Comment = 'is-IS=Sendu quantity yfir 0, eða kveiktu á framboðssviðinu.';
        StockWhenLbl: Label 'The item is Service or Non-Inventory, or capableToPromise is true and Order Promising Setup has no template or worksheet.', Comment = 'is-IS=Varan er þjónusta eða ekki birgðavara, eða capableToPromise er true og Uppsetning pöntunarloforða hefur ekkert sniðmát eða vinnublað.';
        StockFixLbl: Label 'Use an inventory item. For capable to promise, fill in Order Promising Template and Order Promising Worksheet on the Order Promising Setup page.', Comment = 'is-IS=Notaðu birgðavöru. Fyrir hægt að lofa skaltu fylla út Sniðmát pöntunarloforða og Vinnublað pöntunarloforða á síðunni Uppsetning pöntunarloforða.';
        PermissionWhenLbl: Label 'The caller cannot read items, variants, locations or company information, or cannot use the order promising worksheet when capableToPromise is true.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur, afbrigði, staðsetningar eða fyrirtækjaupplýsingar, eða getur ekki notað vinnublað pöntunarloforða þegar capableToPromise er true.';
        PermissionFixLbl: Label 'Assign the Bifrost "Read-Only" permission set (extended by Inventory read permissions) and a Business Central permission set that can read these tables. Capable to promise also needs a permission set that can insert and delete requisition lines.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið þessar töflur. Hægt að lofa þarf einnig heimildasafn sem getur stofnað og eytt innkaupatillögulínum.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, QuantityWhenLbl, QuantityFixLbl));
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
        Effect.Add('changes', 'None is kept. Available to promise only reads. With capableToPromise true, Business Central builds requisition lines in the order promising worksheet to find a date, and the call deletes them again before it answers. No order promising lines, reservations or number series are used.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Availability domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read items, item variants, locations and company information.');
        Preconditions.Add('For capableToPromise: Order Promising Setup has a template and a worksheet, and the caller can insert and delete requisition lines.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.AvailabilityByPeriod.Get', 'Use it for the projected availability of an item per calendar period.'));
        Related.Add(ContractMgt.RelatedEntry('Item.Availability.Get', 'Use it for the availability of items per location on one delivery date.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Ask when 5 pieces can be promised', Comment = 'is-IS=Spyrja hvenær hægt er að lofa 5 stykkjum';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"type":"Inventory.AvailableToPromise.Get","data":{"itemNo":"1000","location":"BLUE","quantity":5,"requestedDate":"2026-11-20"}}',
            '{"status":"Success","itemNo":"1000","description":"Bicycle","variant":"","location":"BLUE","baseUnitOfMeasure":"PCS","quantity":5,"requestedDate":"2026-11-20","availableOnRequestedDate":3,"canPromiseOnRequestedDate":false,"earliestDate":"2026-11-27","basis":"availableToPromise","availableToPromiseDate":"2026-11-27","capableToPromise":false,"capableToPromiseDate":""}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Answers when a quantity of an item can be promised, as the Order Promising page does: the quantity available to promise on the requested date and the earliest date the whole quantity is available. Capable to promise is an option and is off by default. Nothing is kept.', Comment = 'is-IS=Svarar hvenær hægt er að lofa magni af vöru, eins og síðan Pöntunarloforð gerir: magninu sem er tiltækt til loforðs á umbeðinni dagsetningu og fyrstu dagsetningu sem allt magnið er tiltækt. Hægt að lofa er valkostur og er sjálfgefið slökkt. Ekkert er geymt.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'quantity is in the base unit of measure. availableOnRequestedDate is the projected quantity on that day, without later receipts. earliestDate uses the Check-Avail. Period Calc. and Check-Avail. Time Bucket fields on Company Information, as Order Promising does, and leaves out drop shipments. earliestDate is on or after requestedDate; it is empty when the quantity is not available inside that horizon. With capableToPromise true, capable to promise is also run, and earliestDate is the earlier of the two dates; basis says which one. No order promising lines, reservations or document numbers are created, and the requisition lines capable to promise needs are deleted before the answer, so the call can be repeated freely. variant and location are exact codes, not filter expressions.', Comment = 'is-IS=quantity er í grunnmælieiningu. availableOnRequestedDate er áætlað magn þann dag, án síðari móttöku. earliestDate notar reitina Útreikn. tímabils framboðsathugunar og Tímabil framboðsathugunar í Fyrirtækjaupplýsingum, eins og Pöntunarloforð gerir, og undanskilur beinar sendingar. earliestDate er sama dag eða eftir requestedDate; hún er tóm þegar magnið er ekki tiltækt innan þess tímabils. Með capableToPromise true er hægt að lofa einnig keyrt og earliestDate er fyrri dagsetningin af þeim tveimur; basis segir hvor. Engar pöntunarloforðslínur, fráteknir eða skjalanúmer eru stofnuð og innkaupatillögulínunum sem hægt að lofa þarf er eytt fyrir svarið, svo endurtaka má kallið að vild. variant og location eru nákvæmir kóðar, ekki síutjáningar.';
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
        Item: Record Item;
        CompanyInformation: Record "Company Information";
        AvailableToPromise: Codeunit "Available to Promise";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Text;
        VariantCode: Text;
        LocationCode: Text;
        DateText: Text;
        Quantity: Decimal;
        RequestedDate: Date;
        AtpDate: Date;
        CtpDate: Date;
        EarliestDate: Date;
        AvailableOnDate: Decimal;
        AvailableAtEarliest: Decimal;
        UseCapable: Boolean;
        Basis: Text;
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
        if RequestJson.Contains('variant') then;
        if RequestJson.Contains('location') then;
        if RequestJson.Contains('quantity') then;
        if RequestJson.Contains('requestedDate') then;
        if RequestJson.Contains('capableToPromise') then;
        if not ReadText(Argument, RequestJson, ItemNoKeyTok, true, ItemNo) then
            exit;
        if not ReadText(Argument, RequestJson, VariantKeyTok, false, VariantCode) then
            exit;
        if not ReadText(Argument, RequestJson, LocationKeyTok, false, LocationCode) then
            exit;
        if not ReadQuantity(Argument, RequestJson, Quantity) then
            exit;
        if not ReadDate(Argument, RequestJson, RequestedDateKeyTok, DateText, RequestedDate) then
            exit;
        if not ReadBoolean(Argument, RequestJson, CapableKeyTok, UseCapable) then
            exit;
        if not LoadItem(Argument, ItemNo, VariantCode, LocationCode, Item) then
            exit;
        if UseCapable then
            if not AssertCanUseCapable(Argument) then
                exit;

        CompanyInformation.Get();
        AvailableOnDate := CalcAvailableOnDate(Item, RequestedDate);
        AtpDate := AvailableToPromise.CalcEarliestAvailabilityDate(
            Item, Quantity, RequestedDate, 0, 0D, AvailableAtEarliest,
            CompanyInformation."Check-Avail. Time Bucket", CompanyInformation."Check-Avail. Period Calc.");
        // Native ATP can return an earlier receipt; the promise starts at the requested date.
        if (AtpDate <> 0D) and (AtpDate < RequestedDate) then
            AtpDate := RequestedDate;
        EarliestDate := AtpDate;
        if AtpDate <> 0D then
            Basis := AvailableBasisTok;
        if UseCapable then begin
            CtpDate := CalcCapable(Item, VariantCode, LocationCode, RequestedDate, Quantity, CompanyInformation);
            if (CtpDate <> 0D) and ((EarliestDate = 0D) or (CtpDate < EarliestDate)) then begin
                EarliestDate := CtpDate;
                Basis := CapableBasisTok;
            end;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('description', Item.Description);
        ResponseJson.Add('variant', VariantCode);
        ResponseJson.Add('location', LocationCode);
        ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        ResponseJson.Add('quantity', Quantity);
        ResponseJson.Add('requestedDate', Format(RequestedDate, 0, 9));
        ResponseJson.Add('availableOnRequestedDate', AvailableOnDate);
        ResponseJson.Add('canPromiseOnRequestedDate', EarliestDate = RequestedDate);
        ResponseJson.Add('earliestDate', DateOrEmpty(EarliestDate));
        ResponseJson.Add('basis', Basis);
        ResponseJson.Add('availableToPromiseDate', DateOrEmpty(AtpDate));
        ResponseJson.Add('capableToPromise', UseCapable);
        ResponseJson.Add('capableToPromiseDate', DateOrEmpty(CtpDate));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CalcAvailableOnDate(var Item: Record Item; RequestedDate: Date): Decimal
    var
        DatedItem: Record Item;
        AvailableToPromise: Codeunit "Available to Promise";
    begin
        // The projected quantity on the requested date: everything up to and including that day, and nothing after it.
        // Whether the quantity can be promised then follows earliestDate.
        DatedItem.Copy(Item);
        DatedItem.SetRange("Date Filter", 0D, RequestedDate);
        exit(
            AvailableToPromise.CalcAvailableInventory(DatedItem) +
            AvailableToPromise.CalcScheduledReceipt(DatedItem) - AvailableToPromise.CalcReservedReceipt(DatedItem) -
            (AvailableToPromise.CalcGrossRequirement(DatedItem) - AvailableToPromise.CalcReservedRequirement(DatedItem)));
    end;

    local procedure CalcCapable(var Item: Record Item; VariantCode: Text; LocationCode: Text; RequestedDate: Date; Quantity: Decimal; CompanyInformation: Record "Company Information") CtpDate: Date
    var
        CapableToPromise: Codeunit "Capable to Promise";
        OrderPromisingId: Code[20];
        LastValidLine: Integer;
    begin
        // A private promising id, so only the requisition lines of this call are removed; no number series is used.
        OrderPromisingId := CopyStr('ORI' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(OrderPromisingId));
        LastValidLine := 1;
        CtpDate := CapableToPromise.CalcCapableToPromiseDate(
            Item."No.", CopyStr(VariantCode, 1, 10), CopyStr(LocationCode, 1, 10), RequestedDate, Quantity, Item."Base Unit of Measure",
            OrderPromisingId, 10000, LastValidLine,
            CompanyInformation."Check-Avail. Time Bucket", CompanyInformation."Check-Avail. Period Calc.");
        CapableToPromise.RemoveReqLines(OrderPromisingId, 0, 0, false);
    end;

    local procedure CanReadSources(): Boolean
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Location: Record Location;
        CompanyInformation: Record "Company Information";
    begin
        exit(Item.ReadPermission() and ItemVariant.ReadPermission() and Location.ReadPermission() and CompanyInformation.ReadPermission());
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainDisabledErr: Label 'The Availability domain is turned off for this company.', Comment = 'is-IS=Framboðssviðið er slökkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Ask an administrator with the Inv. Posting Gate permission set to turn the domain on from the Inventory Setup page. Data.Records.Set cannot change this setup.', Comment = 'is-IS=Biddu kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á sviðinu á síðunni Uppsetning birgða. Data.Records.Set getur ekki breytt þessari uppsetningu.';
    begin
        if not InventorySetup.ReadPermission() then begin
            RespondPermission(Argument);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Availability) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        if CanReadSources() then
            exit(true);
        RespondPermission(Argument);
        exit(false);
    end;

    local procedure AssertCanUseCapable(var Argument: Record "Message Argument ori"): Boolean
    var
        OrderPromisingSetup: Record "Order Promising Setup";
        RequisitionLine: Record "Requisition Line";
        SetupErr: Label 'Capable to promise needs an order promising template and worksheet.', Comment = 'is-IS=Hægt að lofa þarf sniðmát og vinnublað pöntunarloforða.';
        SetupNextStepLbl: Label 'Fill in Order Promising Template and Order Promising Worksheet on the Order Promising Setup page, or send capableToPromise false.', Comment = 'is-IS=Fylltu út Sniðmát pöntunarloforða og Vinnublað pöntunarloforða á síðunni Uppsetning pöntunarloforða, eða sendu capableToPromise false.';
        PermissionErr: Label 'Capable to promise needs permission to insert and delete requisition lines.', Comment = 'is-IS=Hægt að lofa þarf heimild til að stofna og eyða innkaupatillögulínum.';
        PermissionNextStepLbl: Label 'Assign a Business Central permission set that can insert and delete requisition lines, or send capableToPromise false.', Comment = 'is-IS=Úthlutaðu Business Central heimildasafni sem getur stofnað og eytt innkaupatillögulínum, eða sendu capableToPromise false.';
    begin
        if not (OrderPromisingSetup.ReadPermission() and RequisitionLine.ReadPermission() and RequisitionLine.WritePermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, CapableKeyTok, 'true', '', PermissionNextStepLbl);
            exit(false);
        end;
        if OrderPromisingSetup.Get() then
            if (OrderPromisingSetup."Order Promising Template" <> '') and (OrderPromisingSetup."Order Promising Worksheet" <> '') then
                exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, SetupErr, CapableKeyTok, 'true', 'Order Promising Setup', SetupNextStepLbl);
        exit(false);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo, variant, location, quantity, requestedDate and capableToPromise.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, variant, location, quantity, requestedDate og capableToPromise.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ItemNoKeyTok, VariantKeyTok, LocationKeyTok, QuantityKeyTok, RequestedDateKeyTok, CapableKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, KeyName, KeyName, '', UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure LoadItem(var Argument: Record "Message Argument ori"; ItemNo: Text; VariantCode: Text; LocationCode: Text; var Item: Record Item): Boolean
    var
        ItemVariant: Record "Item Variant";
        Location: Record Location;
        ItemNotFoundErr: Label 'The item does not exist.', Comment = 'is-IS=Varan er ekki til.';
        ItemNextStepLbl: Label 'Check the item no.', Comment = 'is-IS=Athugaðu vörunúmerið.';
        VariantNotFoundErr: Label 'The variant does not exist on the item.', Comment = 'is-IS=Afbrigðið er ekki til á vörunni.';
        VariantNextStepLbl: Label 'Check the variant code.', Comment = 'is-IS=Athugaðu afbrigðiskóðann.';
        LocationNotFoundErr: Label 'The location does not exist.', Comment = 'is-IS=Staðsetningin er ekki til.';
        LocationNextStepLbl: Label 'Check the location code.', Comment = 'is-IS=Athugaðu staðsetningarkóðann.';
        StockErr: Label 'Service and non-inventory items have no availability.', Comment = 'is-IS=Þjónustuvörur og vörur sem eru ekki birgðavörur hafa ekkert framboð.';
        StockNextStepLbl: Label 'Use an inventory item.', Comment = 'is-IS=Notaðu birgðavöru.';
    begin
        if (StrLen(ItemNo) > MaxStrLen(Item."No.")) or not Item.Get(CopyStr(ItemNo, 1, MaxStrLen(Item."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, ItemNotFoundErr, ItemNoKeyTok, CopyStr(ItemNo, 1, 250), '', ItemNextStepLbl);
            exit(false);
        end;
        if Item.Type in [Item.Type::Service, Item.Type::"Non-Inventory"] then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StockErr, ItemNoKeyTok, Item."No.", 'Inventory', StockNextStepLbl);
            exit(false);
        end;
        if VariantCode <> '' then begin
            ItemVariant.SetLoadFields(Code);
            if (StrLen(VariantCode) > MaxStrLen(ItemVariant.Code)) or not ItemVariant.Get(Item."No.", CopyStr(VariantCode, 1, MaxStrLen(ItemVariant.Code))) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, VariantNotFoundErr, VariantKeyTok, CopyStr(VariantCode, 1, 250), '', VariantNextStepLbl);
                exit(false);
            end;
            Item.SetRange("Variant Filter", ItemVariant.Code);
        end;
        if LocationCode <> '' then begin
            Location.SetLoadFields(Code);
            if (StrLen(LocationCode) > MaxStrLen(Location.Code)) or not Location.Get(CopyStr(LocationCode, 1, MaxStrLen(Location.Code))) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, LocationNotFoundErr, LocationKeyTok, CopyStr(LocationCode, 1, 250), '', LocationNextStepLbl);
                exit(false);
            end;
            Item.SetRange("Location Filter", Location.Code);
        end;
        Item.SetRange("Drop Shipment Filter", false);
        exit(true);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not GetPresentToken(RequestJson, KeyName, Token) then begin
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

    local procedure ReadQuantity(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Quantity: Decimal): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        QuantityErr: Label 'quantity must be above 0.', Comment = 'is-IS=quantity verður að vera yfir 0.';
        QuantityNextStepLbl: Label 'Send a quantity above 0, in the base unit of measure of the item.', Comment = 'is-IS=Sendu quantity yfir 0, í grunnmælieiningu vörunnar.';
    begin
        Quantity := 0;
        if not GetPresentToken(RequestJson, QuantityKeyTok, Token) then begin
            RespondMissing(Argument, QuantityKeyTok);
            exit(false);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, QuantityKeyTok, '', DecimalExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (Raw in ['true', 'false']) then begin
            RespondFormat(Argument, QuantityKeyTok, Raw, DecimalExpectedTok);
            exit(false);
        end;
        Quantity := Token.AsValue().AsDecimal();
        if Quantity <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QuantityErr, QuantityKeyTok, CopyStr(Raw, 1, 250), '> 0', QuantityNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var DateText: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        DateText := '';
        Value := 0D;
        if not GetPresentToken(RequestJson, KeyName, Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
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
        if DateText = '' then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if not Evaluate(Value, DateText, 9) then begin
            RespondFormat(Argument, KeyName, DateText, DateExpectedTok);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := false;
        if not GetPresentToken(RequestJson, KeyName, Token) then
            exit(true);
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', BooleanExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not (Raw in ['true', 'false']) then begin
            RespondFormat(Argument, KeyName, Raw, BooleanExpectedTok);
            exit(false);
        end;
        Value := Raw = 'true';
        exit(true);
    end;

    local procedure GetPresentToken(RequestJson: JsonObject; KeyName: Text; var Token: JsonToken): Boolean
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(false);
        exit(true);
    end;

    local procedure DateOrEmpty(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori"; KeyName: Text)
    var
        MissingErr: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextStepLbl: Label 'Send itemNo, quantity and requestedDate.', Comment = 'is-IS=Sendu itemNo, quantity og requestedDate.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', KeyName, MissingNextStepLbl);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text; Expected: Text)
    var
        FormatErr: Label 'The value has the wrong format.', Comment = 'is-IS=Gildið er á röngu sniði.';
        FormatNextStepLbl: Label 'Send itemNo, variant and location as text, quantity as a number, requestedDate as YYYY-MM-DD and capableToPromise as true or false.', Comment = 'is-IS=Sendu itemNo, variant og location sem texta, quantity sem tölu, requestedDate sem YYYY-MM-DD og capableToPromise sem true eða false.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Received, 1, 250), Expected, FormatNextStepLbl);
    end;

    local procedure RespondPermission(var Argument: Record "Message Argument ori")
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst með lesheimildum birgða og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
    end;
}
