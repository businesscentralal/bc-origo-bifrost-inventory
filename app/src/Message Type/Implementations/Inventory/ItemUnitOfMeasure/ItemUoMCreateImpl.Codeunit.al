namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Foundation.UOM;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemUnitOfMeasure.Create. Creates one new unit of measure on an existing item.
/// Refusals are answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10077012 "Item UoM Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        CodeKeyTok: Label 'code', Locked = true;
        QtyKeyTok: Label 'qtyPerUnitOfMeasure', Locked = true;
        LengthKeyTok: Label 'length', Locked = true;
        WidthKeyTok: Label 'width', Locked = true;
        HeightKeyTok: Label 'height', Locked = true;
        WeightKeyTok: Label 'weight', Locked = true;
        AllowedKeysTok: Label 'itemNo, code, qtyPerUnitOfMeasure, length, width, height, weight', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        NumberExpectedTok: Label 'number', Locked = true;
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

    /// <summary>True when the caller can read items and create item units of measure.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(CanWriteTables());
    end;

    /// <summary>The table this type writes.</summary>
    /// <returns>The Item Unit of Measure table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Unit of Measure");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a unit of measure on an item.', Comment = 'is-IS=Stofnar mælieiningu á vöru.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item unit of measure, new unit, carton, pallet, quantity per unit, weight, dimensions', Comment = 'is-IS=vörumælieining, ný eining, kassi, bretti, magn í einingu, þyngd, mál';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a new unit of measure, such as a carton or a pallet, on an existing item.', Comment = 'is-IS=Stofnaðu nýja mælieiningu, til dæmis kassa eða bretti, á vöru sem er til.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Envelope chapter.</summary>
    /// <param name="Envelope">Receives the envelope.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The item is named under data.itemNo and the new unit under data.code; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Target chapter.</summary>
    /// <param name="Target">Receives the target entries.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ItemTargetLbl: Label 'The existing item that receives the new unit of measure.', Comment = 'is-IS=Varan sem er til og fær nýju mælieininguna.';
        QtyTargetLbl: Label 'How many base units one new unit holds.', Comment = 'is-IS=Hversu margar grunneiningar ein ný eining inniheldur.';
        CodeTargetLbl: Label 'The code of the new unit of measure. It must be a unit of measure defined in Business Central and must not exist on the item yet.', Comment = 'is-IS=Kóði nýju mælieiningarinnar. Hann verður að vera skilgreindur mælieiningarkóði í Business Central og má ekki vera til á vörunni.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', ItemTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.code', 'text', CodeTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.qtyPerUnitOfMeasure', 'number', QtyTargetLbl));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemNoLbl: Label 'Number of an existing item, at most 20 characters. Required.', Comment = 'is-IS=Númer vöru sem er til, mest 20 stafir. Skylt.';
        CodeLbl: Label 'Code of the new unit of measure, at most 10 characters. Required. It must exist as a unit of measure in Business Central. A code that already exists on the item is refused.', Comment = 'is-IS=Kóði nýju mælieiningarinnar, mest 10 stafir. Skylt. Hann verður að vera til sem mælieining í Business Central. Kóða sem er þegar til á vörunni er hafnað.';
        QtyLbl: Label 'How many base units one new unit holds, a JSON number greater than 0. Required.', Comment = 'is-IS=Hversu margar grunneiningar ein ný eining inniheldur, JSON-tala stærri en 0. Skylt.';
        LengthLbl: Label 'Length of one unit, a JSON number of 0 or more. Optional.', Comment = 'is-IS=Lengd einnar einingar, JSON-tala 0 eða hærri. Valfrjálst.';
        WidthLbl: Label 'Width of one unit, a JSON number of 0 or more. Optional.', Comment = 'is-IS=Breidd einnar einingar, JSON-tala 0 eða hærri. Valfrjálst.';
        HeightLbl: Label 'Height of one unit, a JSON number of 0 or more. Optional.', Comment = 'is-IS=Hæð einnar einingar, JSON-tala 0 eða hærri. Valfrjálst.';
        WeightLbl: Label 'Weight of one unit, a JSON number of 0 or more. Optional.', Comment = 'is-IS=Þyngd einnar einingar, JSON-tala 0 eða hærri. Valfrjálst.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('code', 'string', true, CodeLbl));
        Parameters.Add(ContractMgt.Parameter('qtyPerUnitOfMeasure', 'number', true, QtyLbl));
        Parameters.Add(ContractMgt.Parameter('length', 'number', false, LengthLbl));
        Parameters.Add(ContractMgt.Parameter('width', 'number', false, WidthLbl));
        Parameters.Add(ContractMgt.Parameter('height', 'number', false, HeightLbl));
        Parameters.Add(ContractMgt.Parameter('weight', 'number', false, WeightLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        GetImpl: Codeunit "Item UoM Get Impl ori";
        Fields: JsonArray;
        UnitField: JsonObject;
    begin
        UnitField := ContractMgt.ResponseField('unit', 'object', 'The created unit of measure as it was saved.');
        UnitField.Add('children', GetImpl.UnitChildren());
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', 'Always true on success: the call only creates units.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number the unit belongs to.'));
        Fields.Add(UnitField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'itemNo, code or qtyPerUnitOfMeasure is missing or empty.', Comment = 'is-IS=itemNo, code eða qtyPerUnitOfMeasure vantar eða er tómt.';
        MissingFixLbl: Label 'Send the number of an existing item, the code of the new unit and its quantity per unit of measure.', Comment = 'is-IS=Sendu númer vöru sem er til, kóða nýju einingarinnar og magn hennar í mælieiningu.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send itemNo and code as text, and qtyPerUnitOfMeasure, length, width, height and weight as JSON numbers.', Comment = 'is-IS=Sendu itemNo og code sem texta, og qtyPerUnitOfMeasure, length, width, height og weight sem JSON-tölur.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        NotFoundWhenLbl: Label 'No item matched itemNo, or code is not a unit of measure defined in Business Central.', Comment = 'is-IS=Engin vara passaði við itemNo, eða code er ekki mælieining skilgreind í Business Central.';
        InvalidWhenLbl: Label 'A text is longer than its field, qtyPerUnitOfMeasure is not greater than 0, or a dimension or the weight is negative.', Comment = 'is-IS=Texti er lengri en reiturinn hans, qtyPerUnitOfMeasure er ekki stærra en 0, eða mál eða þyngd er neikvætt.';
        InvalidFixLbl: Label 'Send an itemNo of at most 20 characters, a code of at most 10, a quantity per unit of measure greater than 0 and dimensions and weight of 0 or more.', Comment = 'is-IS=Sendu itemNo sem er mest 20 stafir, code sem er mest 10, magn í mælieiningu stærra en 0 og mál og þyngd 0 eða hærra.';
        ExistsWhenLbl: Label 'The item already has a unit of measure with that code. When item ledger entries use it, its quantity per unit of measure cannot change.', Comment = 'is-IS=Varan hefur þegar mælieiningu með þeim kóða. Þegar birgðafærslur nota hana má ekki breyta magni í mælieiningu.';
        PermissionWhenLbl: Label 'The caller cannot read items or create item units of measure.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur eða stofnað vörumælieiningar.';
        NativeWhenLbl: Label 'Business Central refuses the save itself, after the request was checked. Nothing is saved.', Comment = 'is-IS=Business Central hafnar sjálfri vistuninni eftir að beiðnin var yfirfarin. Ekkert er vistað.';
        NativeFixLbl: Label 'Read the error text, correct the cause in Business Central and send the call again.', Comment = 'is-IS=Lestu villutextann, lagaðu orsökina í Business Central og sendu kallið aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, ItemNotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ExistsWhenLbl, ExistsNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeFixLbl));
        exit(true);
    end;

    /// <summary>Effect chapter: writes one new row, does not post.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The item named in itemNo exists.');
        Preconditions.Add('The unit of measure code named in code exists in Business Central.');
        Preconditions.Add('The item has no unit of measure with the code named in code yet.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Creates one new unit of measure on an existing item. Existing units, the base unit and the item itself are not changed, and nothing is deleted or posted. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Metering chapter: not metered.</summary>
    /// <param name="Metering">Unused.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Related chapter.</summary>
    /// <param name="Related">Receives the related types.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        GetLbl: Label 'Read the units of measure an item already has, with the base unit flagged, instead of creating one.', Comment = 'is-IS=Lesa mælieiningarnar sem vara hefur þegar, með grunneininguna merkta, í stað þess að stofna nýja.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemUnitOfMeasure.Get', GetLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    /// <param name="Workflow">Receives the steps.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemUnitOfMeasure.Get', 'Read the units of the item to check that the code is not used yet.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemUnitOfMeasure.Create', 'Create the new unit.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemUnitOfMeasure.Get', 'Read the unit back.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create a box of six for an item', Comment = 'is-IS=Stofna kassa með sex stykkjum fyrir vöru';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemUnitOfMeasure.Create","data":{"itemNo":"1896-S","code":"BOX","qtyPerUnitOfMeasure":6,"weight":2.5}}', '{"status":"Success","created":true,"itemNo":"1896-S","unit":{"code":"BOX","qtyPerUnitOfMeasure":6,"isBaseUnit":false,"length":0,"width":0,"height":0,"cubage":0,"weight":2.5,"hasLedgerEntries":false,"systemId":"6b9a7d1e-0000-0000-0000-000000000001"}}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates a new unit of measure on an existing item from itemNo, code and qtyPerUnitOfMeasure, with optional length, width, height and weight. The answer is the saved unit with quantity per unit of measure, base unit flag, dimensions, cubage, weight and system id.', Comment = 'is-IS=Stofnar nýja mælieiningu á vöru sem er til út frá itemNo, code og qtyPerUnitOfMeasure, með valfrjálsri lengd, breidd, hæð og þyngd. Svarið er vistaða einingin með magni í mælieiningu, grunneiningarmerki, málum, rúmmáli, þyngd og kerfiskenni.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A successful call saves one new unit of measure. A refusal saves nothing. The call never changes the quantity per unit of an existing unit: when the code already exists, it is refused with PreconditionFailed, and the refusal says so when item ledger entries use the unit. The call does not change the base unit of the item, does not delete anything and does not post. Generic data writes to item units of measure are refused, so use this call. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Kall sem tekst vistar eina nýja mælieiningu. Höfnun vistar ekkert. Kallið breytir aldrei magni í mælieiningu sem er til: sé kóðinn þegar til er því hafnað með PreconditionFailed, og höfnunin segir það þegar birgðafærslur nota eininguna. Kallið breytir ekki grunneiningu vörunnar, eyðir engu og bókar ekki. Almennum gagnaskrifum í vörumælieiningar er hafnað, svo notaðu þetta kall. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Message direction.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs Inventory.ItemUnitOfMeasure.Create. Validates the whole request, then writes in an isolated Codeunit.Run.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('qtyPerUnitOfMeasure') then;
        if RequestJson.Contains('length') then;
        if RequestJson.Contains('width') then;
        if RequestJson.Contains('height') then;
        if RequestJson.Contains('weight') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item UoM Create Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item UoM Create Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure CanWriteTables(): Boolean
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        exit(Item.ReadPermission() and ItemUnitOfMeasure.ReadPermission() and ItemUnitOfMeasure.WritePermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanWriteTables()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ItemNoKeyTok, CodeKeyTok, QtyKeyTok, LengthKeyTok, WidthKeyTok, HeightKeyTok, WeightKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStep());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Item: Record Item;
        UnitOfMeasure: Record "Unit of Measure";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        GetImpl: Codeunit "Item UoM Get Impl ori";
        ItemNoText: Text;
        CodeText: Text;
        Qty: Decimal;
        ItemNoMissingErr: Label 'itemNo is missing or empty.', Comment = 'is-IS=itemNo vantar eða er tómt.';
        ItemNoMissingNextStepLbl: Label 'Send the number of the item that gets the new unit of measure.', Comment = 'is-IS=Sendu númer vörunnar sem fær nýju mælieininguna.';
        CodeMissingErr: Label 'code is missing or empty.', Comment = 'is-IS=code vantar eða er tómt.';
        CodeMissingNextStepLbl: Label 'Send the code of the new unit of measure, at most 10 characters.', Comment = 'is-IS=Sendu kóða nýju mælieiningarinnar, mest 10 stafir.';
        QtyMissingErr: Label 'qtyPerUnitOfMeasure is missing.', Comment = 'is-IS=qtyPerUnitOfMeasure vantar.';
        QtyMissingNextStepLbl: Label 'Send qtyPerUnitOfMeasure as a JSON number greater than 0.', Comment = 'is-IS=Sendu qtyPerUnitOfMeasure sem JSON-tölu stærri en 0.';
        QtyNotPositiveErr: Label 'qtyPerUnitOfMeasure must be greater than 0.', Comment = 'is-IS=qtyPerUnitOfMeasure verður að vera stærra en 0.';
        QtyNotPositiveNextStepLbl: Label 'Send how many base units one new unit holds, a number greater than 0.', Comment = 'is-IS=Sendu hversu margar grunneiningar ein ný eining inniheldur, tölu stærri en 0.';
        ItemNotFoundErr: Label 'Item %1 does not exist.', Comment = '%1 = item number, is-IS=Vara %1 er ekki til.';
        UnitNotFoundErr: Label 'Unit of measure %1 is not defined in Business Central.', Comment = '%1 = unit of measure code, is-IS=Mælieining %1 er ekki skilgreind í Business Central.';
        UnitNotFoundNextStepLbl: Label 'Create the unit of measure in Business Central first, or send a code that exists in the Units of Measure list.', Comment = 'is-IS=Stofnaðu mælieininguna í Business Central fyrst, eða sendu kóða sem er til í mælieininga-listanum.';
        ExistsErr: Label 'Item %1 already has unit of measure %2.', Comment = '%1 = item number, %2 = unit of measure code, is-IS=Vara %1 hefur þegar mælieininguna %2.';
        ExistsWithEntriesErr: Label 'Item %1 already has unit of measure %2, and item ledger entries use it, so its quantity per unit of measure cannot change.', Comment = '%1 = item number, %2 = unit of measure code, is-IS=Vara %1 hefur þegar mælieininguna %2 og birgðafærslur nota hana, svo ekki má breyta magni í mælieiningu.';
        NotExistingExpectedLbl: Label 'a unit of measure code not used on the item', Comment = 'is-IS=mælieiningarkóði sem er ekki notaður á vörunni';
    begin
        if not RequireText(Argument, RequestJson, ItemNoKeyTok, ItemNoMissingErr, ItemNoMissingNextStepLbl) then
            exit(false);
        if not RequireText(Argument, RequestJson, CodeKeyTok, CodeMissingErr, CodeMissingNextStepLbl) then
            exit(false);
        if not RequestJson.Contains(QtyKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, QtyMissingErr, QtyKeyTok, '', NumberExpectedTok, QtyMissingNextStepLbl);
            exit(false);
        end;
        if not ReadNumber(Argument, RequestJson, QtyKeyTok, Qty) then
            exit(false);
        if Qty <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QtyNotPositiveErr, QtyKeyTok, Format(Qty, 0, 9), '> 0', QtyNotPositiveNextStepLbl);
            exit(false);
        end;
        if not OptionalDimension(Argument, RequestJson, LengthKeyTok) then
            exit(false);
        if not OptionalDimension(Argument, RequestJson, WidthKeyTok) then
            exit(false);
        if not OptionalDimension(Argument, RequestJson, HeightKeyTok) then
            exit(false);
        if not OptionalDimension(Argument, RequestJson, WeightKeyTok) then
            exit(false);
        ItemNoText := ReadText(RequestJson, ItemNoKeyTok);
        CodeText := ReadText(RequestJson, CodeKeyTok);
        if not CheckLength(Argument, ItemNoKeyTok, ItemNoText, MaxStrLen(Item."No.")) then
            exit(false);
        if not CheckLength(Argument, CodeKeyTok, CodeText, MaxStrLen(ItemUnitOfMeasure.Code)) then
            exit(false);
        Item.SetLoadFields("No.");
        if not Item.Get(CopyStr(ItemNoText, 1, MaxStrLen(Item."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemNotFoundErr, UpperCase(ItemNoText)), ItemNoKeyTok, CopyStr(ItemNoText, 1, 250), ItemNoKeyTok, ItemNotFoundNextStep());
            exit(false);
        end;
        UnitOfMeasure.SetLoadFields(Code);
        if not UnitOfMeasure.Get(CopyStr(CodeText, 1, MaxStrLen(UnitOfMeasure.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnitNotFoundErr, UpperCase(CodeText)), CodeKeyTok, CopyStr(CodeText, 1, 250), CodeKeyTok, UnitNotFoundNextStepLbl);
            exit(false);
        end;
        ItemUnitOfMeasure.SetLoadFields("Item No.", Code);
        if ItemUnitOfMeasure.Get(Item."No.", UnitOfMeasure.Code) then begin
            if GetImpl.HasLedgerEntries(Item."No.", UnitOfMeasure.Code) then
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ExistsWithEntriesErr, Item."No.", UnitOfMeasure.Code), CodeKeyTok, CopyStr(CodeText, 1, 250), NotExistingExpectedLbl, ExistsNextStep())
            else
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ExistsErr, Item."No.", UnitOfMeasure.Code), CodeKeyTok, CopyStr(CodeText, 1, 250), NotExistingExpectedLbl, ExistsNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure OptionalDimension(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Value: Decimal;
        NegativeErr: Label '%1 must be 0 or more.', Comment = '%1 = key, is-IS=%1 verður að vera 0 eða hærra.';
        NegativeNextStepLbl: Label 'Send %1 as a number of 0 or more, or leave it out.', Comment = '%1 = key, is-IS=Sendu %1 sem tölu 0 eða hærri, eða slepptu því.';
    begin
        if not RequestJson.Contains(KeyName) then
            exit(true);
        if not ReadNumber(Argument, RequestJson, KeyName, Value) then
            exit(false);
        if Value < 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NegativeErr, KeyName), CopyStr(KeyName, 1, 250), Format(Value, 0, 9), '>= 0', StrSubstNo(NegativeNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadNumber(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be a number.', Comment = '%1 = key, is-IS=%1 verður að vera tala.';
        FormatNextStepLbl: Label 'Send %1 as a JSON number.', Comment = '%1 = key, is-IS=Sendu %1 sem JSON-tölu.';
    begin
        RequestJson.Get(KeyName, Token);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Evaluate(Value, Raw, 9) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure CheckLength(var Argument: Record "Message Argument ori"; KeyName: Text; Value: Text; MaxLength: Integer): Boolean
    var
        TooLongErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=%1 er lengra en %2 stafir.';
        TooLongNextStepLbl: Label 'Send %1 with at most %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=Sendu %1 með mest %2 stöfum.';
    begin
        if StrLen(Value) <= MaxLength then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, KeyName, MaxLength), CopyStr(KeyName, 1, 250), CopyStr(Value, 1, 250), Format(MaxLength, 0, 9), StrSubstNo(TooLongNextStepLbl, KeyName, MaxLength));
        exit(false);
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MissingErr: Text; MissingNextStep: Text): Boolean
    begin
        if not RequestJson.Contains(KeyName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CopyStr(KeyName, 1, 250), '', TextExpectedTok, MissingNextStep);
            exit(false);
        end;
        if not OptionalText(Argument, RequestJson, KeyName) then
            exit(false);
        if ReadText(RequestJson, KeyName) = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CopyStr(KeyName, 1, 250), '', TextExpectedTok, MissingNextStep);
            exit(false);
        end;
        exit(true);
    end;

    local procedure OptionalText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
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

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure UnknownNextStep(): Text
    var
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo, code, qtyPerUnitOfMeasure, length, width, height and weight.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, code, qtyPerUnitOfMeasure, length, width, height og weight.';
    begin
        exit(UnknownNextStepLbl);
    end;

    local procedure ItemNotFoundNextStep(): Text
    var
        ItemNotFoundNextStepLbl: Label 'Check the item number. The item must exist before a unit of measure can be created on it.', Comment = 'is-IS=Athugaðu vörunúmerið. Varan verður að vera til áður en hægt er að stofna mælieiningu á henni.';
    begin
        exit(ItemNotFoundNextStepLbl);
    end;

    local procedure ExistsNextStep(): Text
    var
        ExistsNextStepLbl: Label 'Choose another unit of measure code, or read the existing unit with Inventory.ItemUnitOfMeasure.Get.', Comment = 'is-IS=Veldu annan mælieiningarkóða, eða lestu eininguna sem er til með Inventory.ItemUnitOfMeasure.Get.';
    begin
        exit(ExistsNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set with Inventory write permissions and a Business Central permission set that can read items and create item units of measure.', Comment = 'is-IS=Úthlutaðu Bifrost fullum aðgangi með skrifheimildum birgða og Business Central heimildasafni sem getur lesið vörur og stofnað vörumælieiningar.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
