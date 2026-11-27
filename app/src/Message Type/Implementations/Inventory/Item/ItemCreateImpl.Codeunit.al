namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.Item.Create. Creates one item from an item template (table 1382, codeunit Item Templ. Mgt.), so
/// the item gets the template's base unit of measure, posting groups and costing method, then applies the
/// optional description, base unit of measure, unit price and GTIN. Refusals are answered before the
/// write process runs, so nothing is saved.
/// </summary>
codeunit 10076932 "Item Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TemplateCodeKeyTok: Label 'templateCode', Locked = true;
        DescriptionKeyTok: Label 'description', Locked = true;
        BaseUnitKeyTok: Label 'baseUnitOfMeasure', Locked = true;
        UnitPriceKeyTok: Label 'unitPrice', Locked = true;
        GtinKeyTok: Label 'gtin', Locked = true;
        AllowedKeysTok: Label 'templateCode, description, baseUnitOfMeasure, unitPrice, gtin', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        NumberExpectedTok: Label 'number', Locked = true;
        NonNegativeExpectedTok: Label '>= 0', Locked = true;
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

    /// <summary>True when the Attributes domain is on and the caller can create items and their units of measure.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::Attributes) then
            exit(false);
        exit(CanWriteTables());
    end;

    /// <summary>The table this type writes.</summary>
    /// <returns>The Item table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates an item from an item template and answers its number and units of measure.', Comment = 'is-IS=Stofnar vöru út frá vörusniðmáti og svarar númeri hennar og mælieiningum. (GTIN).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item, create, template, unit of measure, GTIN', Comment = 'is-IS=vara, stofna, sniðmát, mælieining, GTIN';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a new item from an item template, with its description, base unit of measure, unit price and GTIN.', Comment = 'is-IS=Stofnaðu nýja vöru út frá vörusniðmáti, með lýsingu, grunnmælieiningu, einingarverði og GTIN.';
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
        Subject.Add('description', 'The template is named under data.templateCode; the item number comes from the number series; subject is not read.');
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
        TargetLbl: Label 'The item template the new item is created from.', Comment = 'is-IS=Vörusniðmátið sem nýja varan er stofnuð út frá.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.templateCode', 'text', TargetLbl));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        TemplateLbl: Label 'Code of an existing item template, at most 20 characters. The template gives the base unit of measure, posting groups, costing method and number series.', Comment = 'is-IS=Kóði vörusniðmáts sem er til, mest 20 stafir. Sniðmátið gefur grunnmælieiningu, bókunarflokka, kostnaðaraðferð og númeraröð.';
        DescriptionLbl: Label 'Description of the item, at most 100 characters.', Comment = 'is-IS=Lýsing vörunnar, mest 100 stafir.';
        BaseUnitLbl: Label 'Code of an existing unit of measure, at most 10 characters. Replaces the base unit of measure of the template.', Comment = 'is-IS=Kóði mælieiningar sem er til, mest 10 stafir. Kemur í stað grunnmælieiningar sniðmátsins.';
        UnitPriceLbl: Label 'Unit price as a number, zero or more.', Comment = 'is-IS=Einingarverð sem tala, núll eða meira.';
        GtinLbl: Label 'GTIN (barcode) of the item, at most 14 characters.', Comment = 'is-IS=GTIN (strikamerki) vörunnar, mest 14 stafir.';
    begin
        Parameters.Add(ContractMgt.Parameter('templateCode', 'string', true, TemplateLbl));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, DescriptionLbl));
        Parameters.Add(ContractMgt.Parameter('baseUnitOfMeasure', 'string', false, BaseUnitLbl));
        Parameters.Add(ContractMgt.Parameter('unitPrice', 'number', false, UnitPriceLbl));
        Parameters.Add(ContractMgt.Parameter('gtin', 'string', false, GtinLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        UnitField: JsonObject;
        UnitChildren: JsonArray;
    begin
        UnitChildren.Add(ContractMgt.ResponseField('code', 'string', 'The unit of measure code.'));
        UnitChildren.Add(ContractMgt.ResponseField('qtyPerUnitOfMeasure', 'number', 'How many base units one of this unit holds; 1 for the base unit of measure.'));
        UnitField := ContractMgt.ResponseField('unitsOfMeasure', 'array', 'Every unit of measure of the new item.');
        UnitField.Add('children', UnitChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The number of the new item.'));
        Fields.Add(ContractMgt.ResponseField('templateCode', 'string', 'The item template the item was created from.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The item description after the save.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure of the item.'));
        Fields.Add(ContractMgt.ResponseField('unitPrice', 'number', 'The unit price of the item.'));
        Fields.Add(ContractMgt.ResponseField('gtin', 'string', 'The GTIN of the item; empty when none was set.'));
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
        MissingWhenLbl: Label 'templateCode is missing or empty.', Comment = 'is-IS=templateCode vantar eða er tómt.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send templateCode, description, baseUnitOfMeasure and gtin as text, and unitPrice as a number.', Comment = 'is-IS=Sendu templateCode, description, baseUnitOfMeasure og gtin sem texta, og unitPrice sem tölu.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        NotFoundWhenLbl: Label 'No item template has the code in templateCode.', Comment = 'is-IS=Ekkert vörusniðmát hefur kóðann í templateCode.';
        UnitWhenLbl: Label 'baseUnitOfMeasure names a unit of measure that does not exist.', Comment = 'is-IS=baseUnitOfMeasure nefnir mælieiningu sem er ekki til.';
        ValueWhenLbl: Label 'A text is longer than its field, unitPrice is below zero, or the Attributes domain is turned off.', Comment = 'is-IS=Texti er lengri en reiturinn hans, unitPrice er undir núlli, eða eiginleikasviðið er óvirkt.';
        ValueFixLbl: Label 'Send templateCode of at most 20 characters, description of at most 100, baseUnitOfMeasure of at most 10, gtin of at most 14 and unitPrice of zero or more, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu templateCode sem er mest 20 stafir, description sem er mest 100, baseUnitOfMeasure sem er mest 10, gtin sem er mest 14 og unitPrice sem er núll eða meira, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        PermissionWhenLbl: Label 'The caller cannot create items or their units of measure.', Comment = 'is-IS=Kallandinn getur ekki stofnað vörur eða mælieiningar þeirra.';
        NativeWhenLbl: Label 'Business Central refuses the save itself after the request was checked, for example when no item number series is set up. Nothing is saved.', Comment = 'is-IS=Business Central hafnar vistuninni sjálfri eftir að beiðnin var athuguð, til dæmis þegar engin vörunúmeraröð er uppsett. Ekkert er vistað.';
        NativeFixLbl: Label 'Read the error text, correct the cause in Business Central and send the call again.', Comment = 'is-IS=Lestu villutextann, lagaðu orsökina í Business Central og sendu kallið aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, TemplateMissingNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, TemplateNotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, UnitWhenLbl, UnitNotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ValueWhenLbl, ValueFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeFixLbl));
        exit(true);
    end;

    /// <summary>Effect chapter: writes (creates one item), does not post, is not irreversible.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The item template named in templateCode exists.');
        Preconditions.Add('A unit of measure named in baseUnitOfMeasure exists.');
        Preconditions.Add('The template or Inventory Setup names an item number series that can give a new number.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Creates one new item with the values of the item template, then sets the description, base unit of measure, unit price and GTIN that were sent. Setting the base unit of measure adds the item unit of measure row for it. Existing items are never changed. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.');
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
        PriceLbl: Label 'Change the unit price of an item that already exists.', Comment = 'is-IS=Breyta einingarverði vöru sem er þegar til.';
        AttributeLbl: Label 'Give the new item its attribute values.', Comment = 'is-IS=Gefa nýju vörunni eiginleikagildi.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Price.Update', PriceLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Create', AttributeLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    /// <param name="Workflow">Receives the steps.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Item.Create', 'Create the item from a template and read its number from the answer.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Attribute.Create', 'Give the new item its attribute values.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create an item from a template with a description and a price', Comment = 'is-IS=Stofna vöru út frá sniðmáti með lýsingu og verði';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.Item.Create","data":{"templateCode":"ITEM","description":"Office chair","baseUnitOfMeasure":"PCS","unitPrice":129.5,"gtin":"5690000000017"}}', '{"status":"Success","itemNo":"1000","templateCode":"ITEM","description":"Office chair","baseUnitOfMeasure":"PCS","unitPrice":129.5,"gtin":"5690000000017","unitsOfMeasure":[{"code":"PCS","qtyPerUnitOfMeasure":1}]}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates one item from an item template, the same way the New action on the Items page does with a template. The item gets the template values, such as base unit of measure, posting groups and costing method, and then the description, base unit of measure, unit price and GTIN that were sent. The answer is the new item number with its units of measure.', Comment = 'is-IS=Stofnar eina vöru út frá vörusniðmáti, á sama hátt og aðgerðin Nýtt á síðunni Vörur gerir með sniðmáti. Varan fær gildi sniðmátsins, svo sem grunnmælieiningu, bókunarflokka og kostnaðaraðferð, og síðan lýsingu, grunnmælieiningu, einingarverð og GTIN sem voru send. Svarið er númer nýju vörunnar með mælieiningum hennar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Each successful call creates a new item, so sending the same request twice gives two items. A refusal creates nothing. The call never changes or deletes an existing item and does not post. The Attributes domain on the Inventory Setup page turns this call on or off. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Hvert kall sem tekst stofnar nýja vöru, svo sama beiðni send tvisvar gefur tvær vörur. Höfnun stofnar ekkert. Kallið breytir aldrei né eyðir vöru sem er til og bókar ekki. Eiginleikasviðið á síðunni Uppsetning birgða kveikir og slekkur á þessu kalli. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';
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

    /// <summary>Runs Inventory.Item.Create. Validates the whole request, then writes in an isolated Codeunit.Run.</summary>
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
        if RequestJson.Contains('templateCode') then;
        if RequestJson.Contains('description') then;
        if RequestJson.Contains('baseUnitOfMeasure') then;
        if RequestJson.Contains('unitPrice') then;
        if RequestJson.Contains('gtin') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item Create Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item Create Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure CanWriteTables(): Boolean
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemTempl: Record "Item Templ.";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        exit(Item.WritePermission() and ItemUnitOfMeasure.WritePermission() and ItemTempl.ReadPermission() and UnitOfMeasure.ReadPermission());
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
            if not (KeyName in [TemplateCodeKeyTok, DescriptionKeyTok, BaseUnitKeyTok, UnitPriceKeyTok, GtinKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStep());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Item: Record Item;
        ItemTempl: Record "Item Templ.";
        UnitOfMeasure: Record "Unit of Measure";
        TemplateText: Text;
        UnitText: Text;
        UnitPrice: Decimal;
        MissingErr: Label 'templateCode is required.', Comment = 'is-IS=templateCode er áskilið.';
        TemplateNotFoundErr: Label 'The item template does not exist.', Comment = 'is-IS=Vörusniðmátið er ekki til.';
        UnitNotFoundErr: Label 'The unit of measure does not exist.', Comment = 'is-IS=Mælieiningin er ekki til.';
        NegativePriceErr: Label 'unitPrice is below zero.', Comment = 'is-IS=unitPrice er undir núlli.';
        NegativePriceNextStepLbl: Label 'Send unitPrice as zero or more.', Comment = 'is-IS=Sendu unitPrice sem núll eða meira.';
    begin
        if not RequestJson.Contains(TemplateCodeKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, TemplateCodeKeyTok, '', TemplateCodeKeyTok, TemplateMissingNextStep());
            exit(false);
        end;
        if not RequireText(Argument, RequestJson, TemplateCodeKeyTok) then
            exit(false);
        TemplateText := ReadText(RequestJson, TemplateCodeKeyTok);
        if TemplateText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, TemplateCodeKeyTok, '', TemplateCodeKeyTok, TemplateMissingNextStep());
            exit(false);
        end;
        if not CheckLength(Argument, TemplateCodeKeyTok, TemplateText, MaxStrLen(ItemTempl.Code)) then
            exit(false);
        if not CheckOptionalText(Argument, RequestJson, DescriptionKeyTok, MaxStrLen(Item.Description)) then
            exit(false);
        if not CheckOptionalText(Argument, RequestJson, BaseUnitKeyTok, MaxStrLen(Item."Base Unit of Measure")) then
            exit(false);
        if not CheckOptionalText(Argument, RequestJson, GtinKeyTok, MaxStrLen(Item.GTIN)) then
            exit(false);
        if RequestJson.Contains(UnitPriceKeyTok) then begin
            if not RequireDecimal(Argument, RequestJson, UnitPriceKeyTok, UnitPrice) then
                exit(false);
            if UnitPrice < 0 then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, NegativePriceErr, UnitPriceKeyTok, Format(UnitPrice, 0, 9), NonNegativeExpectedTok, NegativePriceNextStepLbl);
                exit(false);
            end;
        end;
        ItemTempl.SetLoadFields(Code);
        if not ItemTempl.Get(CopyStr(TemplateText, 1, MaxStrLen(ItemTempl.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, TemplateNotFoundErr, TemplateCodeKeyTok, CopyStr(TemplateText, 1, 250), TemplateCodeKeyTok, TemplateNotFoundNextStep());
            exit(false);
        end;
        UnitText := ReadText(RequestJson, BaseUnitKeyTok);
        if UnitText <> '' then begin
            UnitOfMeasure.SetLoadFields(Code);
            if not UnitOfMeasure.Get(CopyStr(UnitText, 1, MaxStrLen(UnitOfMeasure.Code))) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, UnitNotFoundErr, BaseUnitKeyTok, CopyStr(UnitText, 1, 250), BaseUnitKeyTok, UnitNotFoundNextStep());
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure CheckOptionalText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer): Boolean
    begin
        if not RequestJson.Contains(KeyName) then
            exit(true);
        if not RequireText(Argument, RequestJson, KeyName) then
            exit(false);
        exit(CheckLength(Argument, KeyName, ReadText(RequestJson, KeyName), MaxLength));
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

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
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

    local procedure RequireDecimal(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be a number.', Comment = '%1 = key, is-IS=%1 verður að vera tala.';
        FormatNextStepLbl: Label 'Send %1 as a number, for example 129.5.', Comment = '%1 = key, is-IS=Sendu %1 sem tölu, til dæmis 129.5.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (not Evaluate(Value, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
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

    local procedure TemplateMissingNextStep(): Text
    var
        TemplateMissingNextStepLbl: Label 'Send templateCode with the code of an item template. The Item Templates page lists them.', Comment = 'is-IS=Sendu templateCode með kóða vörusniðmáts. Síðan Vörusniðmát sýnir þau.';
    begin
        exit(TemplateMissingNextStepLbl);
    end;

    local procedure TemplateNotFoundNextStep(): Text
    var
        TemplateNotFoundNextStepLbl: Label 'Check the template code on the Item Templates page, or create the template there first.', Comment = 'is-IS=Athugaðu kóða sniðmátsins á síðunni Vörusniðmát, eða stofnaðu sniðmátið þar fyrst.';
    begin
        exit(TemplateNotFoundNextStepLbl);
    end;

    local procedure UnitNotFoundNextStep(): Text
    var
        UnitNotFoundNextStepLbl: Label 'Send the code of an existing unit of measure from the Units of Measure page, or leave baseUnitOfMeasure out to keep the template unit.', Comment = 'is-IS=Sendu kóða mælieiningar sem er til á síðunni Mælieiningar, eða slepptu baseUnitOfMeasure til að halda einingu sniðmátsins.';
    begin
        exit(UnitNotFoundNextStepLbl);
    end;

    local procedure UnknownNextStep(): Text
    var
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are templateCode, description, baseUnitOfMeasure, unitPrice and gtin.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru templateCode, description, baseUnitOfMeasure, unitPrice og gtin.';
    begin
        exit(UnknownNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set with Inventory write permissions and a Business Central permission set that can create items.', Comment = 'is-IS=Úthlutaðu Bifrost fullum aðgangi með skrifheimildum birgða og Business Central heimildasafni sem getur stofnað vörur.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
