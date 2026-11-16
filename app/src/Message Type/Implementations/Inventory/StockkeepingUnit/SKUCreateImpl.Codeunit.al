namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.SKU.Create. Runs the Create Stockkeeping Unit report (5706) without its request page.
/// Refusals are answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10076995 "SKU Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SKURequest: Codeunit "SKU Request ori";
        ItemFilterKeyTok: Label 'itemFilter', Locked = true;
        LocationFilterKeyTok: Label 'locationFilter', Locked = true;
        VariantFilterKeyTok: Label 'variantFilter', Locked = true;
        CreatePerKeyTok: Label 'createPer', Locked = true;
        InventoryOnlyKeyTok: Label 'itemInInventoryOnly', Locked = true;
        ReplaceKeyTok: Label 'replaceExisting', Locked = true;
        AllowedKeysTok: Label 'itemFilter, locationFilter, variantFilter, createPer, itemInInventoryOnly, replaceExisting', Locked = true;
        CreatePerExpectedTok: Label 'Location|Variant|LocationAndVariant', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Availability, Database::"Stockkeeping Unit", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Stockkeeping Unit");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates stockkeeping units per location and variant for the selected items.', Comment = 'is-IS=Stofnar birgðageymsluvörur fyrir staðsetningar og afbrigði valinna vara.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create stockkeeping units, sku, location, variant, replace', Comment = 'is-IS=stofna birgðageymsluvörur, sku, staðsetning, afbrigði, skipta út';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create the missing stockkeeping units of the items matching an item filter, as the Create Stockkeeping Unit report does.', Comment = 'is-IS=Stofnaðu birgðageymsluvörur sem vantar fyrir vörur sem passa við vörusíu, eins og skýrslan Stofna birgðageymsluvörur gerir.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The items are selected under data.itemFilter; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetLbl: Label 'An Item No. filter that selects the items to make units for.', Comment = 'is-IS=Vörunúmerssía sem velur vörurnar sem á að stofna einingar fyrir.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemFilter', 'filter', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemFilterLbl: Label 'Business Central filter on Item No., for example 1000 or 1000..1100. Required, so a call never makes units for every item by accident.', Comment = 'is-IS=Business Central sía á vörunúmer, til dæmis 1000 eða 1000..1100. Nauðsynleg, svo kall stofni aldrei fyrir slysni einingar fyrir allar vörur.';
        LocationFilterLbl: Label 'Business Central filter on location codes. Omit it to use every location that is not an in-transit location.', Comment = 'is-IS=Business Central sía á staðsetningarkóða. Slepptu henni til að nota allar staðsetningar sem eru ekki flutningsstaðsetningar.';
        VariantFilterLbl: Label 'Business Central filter on variant codes. Omit it to use every variant of the item.', Comment = 'is-IS=Business Central sía á afbrigðiskóða. Slepptu henni til að nota öll afbrigði vörunnar.';
        CreatePerLbl: Label 'Location, Variant or LocationAndVariant. Default Location. Sets what one unit is made per.', Comment = 'is-IS=Location, Variant eða LocationAndVariant. Sjálfgefið Location. Ákveður fyrir hvað ein eining er stofnuð.';
        InventoryOnlyLbl: Label 'true or false. true makes units only for items that have inventory. Default true, as on the report request page.', Comment = 'is-IS=true eða false. true stofnar einingar aðeins fyrir vörur sem eru til á lager. Sjálfgefið true, eins og á beiðnisíðu skýrslunnar.';
        ReplaceLbl: Label 'true or false. true replaces units that already exist with new ones made from the item card. Default false: existing units are kept.', Comment = 'is-IS=true eða false. true skiptir út einingum sem eru til fyrir nýjar einingar úr vöruspjaldinu. Sjálfgefið false: einingar sem eru til haldast.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', true, ItemFilterLbl));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, LocationFilterLbl));
        Parameters.Add(ContractMgt.Parameter('variantFilter', 'string', false, VariantFilterLbl));
        Parameters.Add(ContractMgt.Parameter('createPer', 'string', false, CreatePerLbl));
        Parameters.Add(ContractMgt.Parameter('itemInInventoryOnly', 'boolean', false, InventoryOnlyLbl));
        Parameters.Add(ContractMgt.Parameter('replaceExisting', 'boolean', false, ReplaceLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('itemsMatched', 'integer', 'Number of items that matched itemFilter.'));
        Fields.Add(ContractMgt.ResponseField('created', 'integer', 'Number of stockkeeping units the call added for the matched items.'));
        Fields.Add(ContractMgt.ResponseField('skuCount', 'integer', 'Number of stockkeeping units the matched items have after the call.'));
        Fields.Add(ContractMgt.ResponseField('replaceExisting', 'boolean', 'The replace option that was used.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'itemFilter is missing or empty.', Comment = 'is-IS=itemFilter vantar eða er tómt.';
        MissingFixLbl: Label 'Send itemFilter, a filter on Item No., for example 1000..1100.', Comment = 'is-IS=Sendu itemFilter, síu á vörunúmer, til dæmis 1000..1100.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send the filters and createPer as text, and itemInInventoryOnly and replaceExisting as true or false.', Comment = 'is-IS=Sendu síurnar og createPer sem texta, og itemInInventoryOnly og replaceExisting sem true eða false.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are itemFilter, locationFilter, variantFilter, createPer, itemInInventoryOnly and replaceExisting.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemFilter, locationFilter, variantFilter, createPer, itemInInventoryOnly og replaceExisting.';
        InvalidWhenLbl: Label 'createPer is not Location, Variant or LocationAndVariant, a filter is not valid, or the Availability domain is turned off.', Comment = 'is-IS=createPer er ekki Location, Variant eða LocationAndVariant, sía er ógild, eða framboðssviðið er óvirkt.';
        InvalidFixLbl: Label 'Correct the value, or turn the Availability domain on from the Inventory Setup page.', Comment = 'is-IS=Leiðréttu gildið, eða kveiktu á framboðssviðinu á síðunni Uppsetning birgða.';
        NotFoundWhenLbl: Label 'itemFilter matches no item.', Comment = 'is-IS=itemFilter passar ekki við neina vöru.';
        NotFoundFixLbl: Label 'Check the item filter, or read items with Data.Records.Get.', Comment = 'is-IS=Athugaðu vörusíuna, eða lestu vörur með Data.Records.Get.';
        PermissionWhenLbl: Label 'The caller cannot write stockkeeping units.', Comment = 'is-IS=Kallandinn getur ekki skrifað birgðageymsluvörur.';
        PermissionFixLbl: Label 'Assign a permission set that changes stockkeeping units.', Comment = 'is-IS=Úthlutaðu heimildasafni sem breytir birgðageymsluvörum.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Availability domain is turned on in Inventory Setup.');
        Preconditions.Add('itemFilter matches at least one item.');
        Preconditions.Add('The caller can read items and change stockkeeping units.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Adds stockkeeping units for the matched items. With replaceExisting true, existing units of those items are replaced by units made from the item card, so values edited on the unit are lost. Nothing is posted and no item or ledger entry changes. A failure saves nothing.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        GetLbl: Label 'Read the stockkeeping units and their planning and cost fields.', Comment = 'is-IS=Lesa birgðageymsluvörur og skipulags- og kostnaðarreiti þeirra.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.SKU.Get', GetLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Make units per location for item 1000 and replace existing ones', Comment = 'is-IS=Stofna einingar fyrir hverja staðsetningu vöru 1000 og skipta út þeim sem eru til';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.SKU.Create","data":{"itemFilter":"1000","createPer":"Location","itemInInventoryOnly":false,"replaceExisting":true}}', '{"status":"Success","itemsMatched":1,"created":2,"skuCount":2,"replaceExisting":true}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates stockkeeping units per location, variant or both for the items matching itemFilter, with the options of the Create Stockkeeping Unit report. The new units copy cost and planning values from the item card.', Comment = 'is-IS=Stofnar birgðageymsluvörur fyrir staðsetningu, afbrigði eða hvort tveggja fyrir vörur sem passa við itemFilter, með valkostum skýrslunnar Stofna birgðageymsluvörur. Nýju einingarnar afrita kostnaðar- og skipulagsgildi úr vöruspjaldinu.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'itemFilter is required. Existing units are kept unless replaceExisting is true; skuCount counts replaced units, created counts only units that did not exist before. locationFilter and variantFilter narrow the locations and variants the units are made for. The call does not delete units that fall outside the filters and never changes items.', Comment = 'is-IS=itemFilter er nauðsynlegt. Einingar sem eru til haldast nema replaceExisting sé true; skuCount telur einingar sem var skipt út, created telur aðeins einingar sem voru ekki til áður. locationFilter og variantFilter þrengja staðsetningar og afbrigði sem einingar eru stofnaðar fyrir. Kallið eyðir ekki einingum utan síanna og breytir aldrei vörum.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not SKURequest.AssertCanRun(Argument, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemFilter') then;
        if RequestJson.Contains('locationFilter') then;
        if RequestJson.Contains('variantFilter') then;
        if RequestJson.Contains('createPer') then;
        if RequestJson.Contains('itemInInventoryOnly') then;
        if RequestJson.Contains('replaceExisting') then;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"SKU Create Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"SKU Create Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Item: Record Item;
        ProcCodeunit: Codeunit "SKU Create Proc ori";
        SKUCreationMethod: Enum "SKU Creation Method";
        MethodText: Text;
        MissingErr: Label 'itemFilter is required.', Comment = 'is-IS=itemFilter er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send itemFilter, a filter on Item No., for example 1000..1100.', Comment = 'is-IS=Sendu itemFilter, síu á vörunúmer, til dæmis 1000..1100.';
        MethodErr: Label 'createPer is not a valid creation method.', Comment = 'is-IS=createPer er ekki gild stofnunaraðferð.';
        MethodNextStepLbl: Label 'Send createPer as Location, Variant or LocationAndVariant.', Comment = 'is-IS=Sendu createPer sem Location, Variant eða LocationAndVariant.';
        FilterErr: Label 'A filter is not valid.', Comment = 'is-IS=Sía er ógild.';
        FilterNextStepLbl: Label 'Correct the filter syntax, for example 1000..1100 or 1000|2000.', Comment = 'is-IS=Leiðréttu setningafræði síunnar, til dæmis 1000..1100 eða 1000|2000.';
        NotFoundErr: Label 'itemFilter matches no item.', Comment = 'is-IS=itemFilter passar ekki við neina vöru.';
        NotFoundNextStepLbl: Label 'Check the item filter. Items can be read with Data.Records.Get.', Comment = 'is-IS=Athugaðu vörusíuna. Hægt er að lesa vörur með Data.Records.Get.';
    begin
        if not SKURequest.RejectUnknownKeys(Argument, RequestJson, AllowedKeysTok) then
            exit(false);
        if not (SKURequest.CheckText(Argument, RequestJson, ItemFilterKeyTok, 250) and
                SKURequest.CheckText(Argument, RequestJson, LocationFilterKeyTok, 250) and
                SKURequest.CheckText(Argument, RequestJson, VariantFilterKeyTok, 250) and
                SKURequest.CheckText(Argument, RequestJson, CreatePerKeyTok, 50) and
                SKURequest.CheckBoolean(Argument, RequestJson, InventoryOnlyKeyTok) and
                SKURequest.CheckBoolean(Argument, RequestJson, ReplaceKeyTok))
        then
            exit(false);
        if SKURequest.ReadText(RequestJson, ItemFilterKeyTok) = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, ItemFilterKeyTok, '', ItemFilterKeyTok, MissingNextStepLbl);
            exit(false);
        end;
        if RequestJson.Contains(CreatePerKeyTok) then begin
            MethodText := SKURequest.ReadText(RequestJson, CreatePerKeyTok);
            if not SKURequest.TryParseCreationMethod(MethodText, SKUCreationMethod) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, MethodErr, CreatePerKeyTok, CopyStr(MethodText, 1, 250), CreatePerExpectedTok, MethodNextStepLbl);
                exit(false);
            end;
        end;
        if not ProcCodeunit.TryApplyItemFilters(Item, RequestJson) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FilterErr, ItemFilterKeyTok, CopyStr(SKURequest.ReadText(RequestJson, ItemFilterKeyTok), 1, 250), '', FilterNextStepLbl);
            exit(false);
        end;
        if Item.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, ItemFilterKeyTok, CopyStr(SKURequest.ReadText(RequestJson, ItemFilterKeyTok), 1, 250), '', NotFoundNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;
}
