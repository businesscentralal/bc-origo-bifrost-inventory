namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;

/// <summary>
/// Inventory.NonstockItem.Create. Turns one catalog item (table Nonstock Item) into an item with the
/// catalog item's own item template, the same way the Create Item action on the Catalog Item Card does
/// (codeunit Catalog Item Management). Every refusal is answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10077019 "Nonstock Item Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        EntryNoKeyTok: Label 'entryNo', Locked = true;
        AllowedKeysTok: Label 'entryNo', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

    /// <summary>True when the Catalog Items domain is on and the caller can create items from catalog items.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::CatalogItems) then
            exit(false);
        exit(CanWriteTables());
    end;

    /// <summary>The table this type reads its subject from.</summary>
    /// <returns>The Nonstock Item table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Nonstock Item");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates an item from a catalog item with the item template of the catalog item.', Comment = 'is-IS=Stofnar vöru úr vörulistavöru með vörusniðmáti vörulistavörunnar. (vörulistavara, vara utan birgða, stofna vöru, breyta vörulistavöru).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'catalog item, nonstock item, create item, convert catalog item, item template', Comment = 'is-IS=vörulistavara, vara utan birgða, stofna vöru, breyta vörulistavöru, vörusniðmát';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Turn one catalog item into an item and get the new item number back.', Comment = 'is-IS=Breyttu einni vörulistavöru í vöru og fáðu nýja vörunúmerið til baka.';
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
        Subject.Add('description', 'The catalog item is named under data.entryNo; subject is not read.');
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
        TargetLbl: Label 'The Entry No. of the catalog item to turn into an item.', Comment = 'is-IS=Færslunúmer vörulistavörunnar sem á að breyta í vöru.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'text', TargetLbl));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        EntryNoLbl: Label 'Entry No. of the catalog item, at most 20 characters, as text.', Comment = 'is-IS=Færslunúmer vörulistavörunnar, mest 20 stafir, sem texti.';
    begin
        Parameters.Add(ContractMgt.Parameter('entryNo', 'string', true, EntryNoLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'string', 'The Entry No. of the catalog item.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The No. of the new item. The catalog item now points to it.'));
        Fields.Add(ContractMgt.ResponseField('itemId', 'string', 'The SystemId of the new item.'));
        Fields.Add(ContractMgt.ResponseField('itemTemplateCode', 'string', 'The item template the new item was created from.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The description of the new item.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure of the new item.'));
        Fields.Add(ContractMgt.ResponseField('vendorNo', 'string', 'The vendor of the new item.'));
        Fields.Add(ContractMgt.ResponseField('vendorItemNo', 'string', 'The vendor item number of the new item.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'entryNo is missing or empty.', Comment = 'is-IS=entryNo vantar eða er tómt.';
        FormatWhenLbl: Label 'entryNo is not text.', Comment = 'is-IS=entryNo er ekki texti.';
        FormatFixLbl: Label 'Send entryNo as text.', Comment = 'is-IS=Sendu entryNo sem texta.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. The only allowed key is entryNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Eini leyfði lykillinn er entryNo.';
        TooLongWhenLbl: Label 'entryNo is longer than 20 characters, or the Catalog Items domain is turned off.', Comment = 'is-IS=entryNo er lengra en 20 stafir, eða vörulistavörusviðið er óvirkt.';
        TooLongFixLbl: Label 'Send an entryNo of at most 20 characters, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu entryNo sem er mest 20 stafir, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        NotFoundWhenLbl: Label 'No catalog item has this Entry No.', Comment = 'is-IS=Engin vörulistavara hefur þetta færslunúmer.';
        ConvertedWhenLbl: Label 'The catalog item has already been turned into an item.', Comment = 'is-IS=Vörulistavörunni hefur þegar verið breytt í vöru.';
        SetupWhenLbl: Label 'The catalog item has no vendor, vendor item number, unit of measure or item template, its item template does not exist, the Catalog Item Setup or the item number series is missing, or an item with the number the catalog item would get already exists.', Comment = 'is-IS=Vörulistavöruna vantar lánardrottin, vörunúmer lánardrottins, mælieiningu eða vörusniðmát, vörusniðmát hennar er ekki til, uppsetningu vörulistavara eða númeraröð vöru vantar, eða vara með númerið sem vörulistavaran fengi er þegar til.';
        PermissionWhenLbl: Label 'The caller cannot create items from catalog items.', Comment = 'is-IS=Kallandinn getur ekki stofnað vörur úr vörulistavörum.';
        NativeWhenLbl: Label 'Business Central refuses the item creation itself, after the request was checked. Nothing is saved.', Comment = 'is-IS=Business Central hafnar sjálfri stofnun vörunnar eftir að beiðnin var yfirfarin. Ekkert er vistað.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, EntryNoNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, TooLongWhenLbl, TooLongFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, EntryNoNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ConvertedWhenLbl, ConvertedNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, SetupWhenLbl, CatalogCardNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeNextStep()));
        exit(true);
    end;

    /// <summary>Effect chapter: writes one new item, does not post.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The catalog item exists and has not been turned into an item yet.');
        Preconditions.Add('The catalog item has a vendor, a vendor item number, a unit of measure and an item template that exists.');
        Preconditions.Add('Catalog Item Setup exists, and no item has the number the catalog item would get.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Creates one Item from the catalog item and its item template (fields, dimensions), with its base Item Unit of Measure (and the Unit of Measure when it does not exist), an Item Vendor row and the vendor Item References, and writes the new item number on the catalog item. With the Item No. Series number format the next number of the series is used. Nothing is posted and no ledger entry is written. The item can be deleted again on the Item Card; that clears the item number on the catalog item. A refusal saves nothing.');
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
        ReadLbl: Label 'Find the Entry No. of the catalog item first, or check its Item No. before the call.', Comment = 'is-IS=Finndu fyrst færslunúmer vörulistavörunnar, eða athugaðu vörunúmer hennar fyrir kallið.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', ReadLbl));
        exit(true);
    end;

    /// <summary>Reads the catalog item, creates its item and verifies the saved link.</summary>
    /// <param name="Workflow">Receives the workflow steps.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        ReadLbl: Label 'Read the catalog item from Nonstock Item and check its template and that Item No. is empty.', Comment = 'is-IS=Lestu vörulistavöruna úr Nonstock Item og athugaðu sniðmát hennar og að vörunúmer sé tómt.';
        CreateLbl: Label 'Create the item using the catalog item entryNo and its own item template.', Comment = 'is-IS=Stofnaðu vöruna með entryNo vörulistavörunnar og hennar eigin vörusniðmáti.';
        VerifyLbl: Label 'Read the catalog item again and verify that Item No. matches the returned itemNo.', Comment = 'is-IS=Lestu vörulistavöruna aftur og staðfestu að vörunúmer passi við itemNo í svarinu.';
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', ReadLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.NonstockItem.Create', CreateLbl));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', VerifyLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create an item from a catalog item', Comment = 'is-IS=Stofna vöru úr vörulistavöru';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.NonstockItem.Create","data":{"entryNo":"NS0001"}}', '{"status":"Success","entryNo":"NS0001","itemNo":"70061","itemId":"5f1c2b9e-3a3d-4b8e-9c4f-2f7a1d0e6b11","itemTemplateCode":"ITEM","description":"Office chair, black","baseUnitOfMeasure":"PCS","vendorNo":"10000","vendorItemNo":"CH-100"}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Turns one catalog item into an item, like the Create Item action on the Catalog Item Card. The new item gets its fields and dimensions from the item template of the catalog item, and its description, unit of measure, vendor, prices and weights from the catalog item. The item number follows the number format in Catalog Item Setup. The answer is the new item number.', Comment = 'is-IS=Breytir einni vörulistavöru í vöru, eins og aðgerðin Stofna vöru á vörulistavöruspjaldinu. Nýja varan fær reiti sína og víddir úr vörusniðmáti vörulistavörunnar og lýsingu, mælieiningu, lánardrottin, verð og þyngd úr vörulistavörunni. Vörunúmerið fylgir númerasniðinu í uppsetningu vörulistavara. Svarið er nýja vörunúmerið.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A catalog item is turned into an item once. A second call for the same catalog item is refused with PreconditionFailed and names the item it already has. The call uses the item template of the catalog item; change the template on the Catalog Item Card first to use another one. A refusal leaves the catalog item and every item unchanged. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Vörulistavöru er breytt í vöru einu sinni. Öðru kalli fyrir sömu vörulistavöru er hafnað með PreconditionFailed og vörunni sem hún hefur þegar er lýst. Kallið notar vörusniðmát vörulistavörunnar; breyttu sniðmátinu fyrst á vörulistavöruspjaldinu til að nota annað. Höfnun skilur vörulistavöruna og allar vörur eftir óbreyttar. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';
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

    /// <summary>Runs Inventory.NonstockItem.Create. Checks the whole request, then writes in an isolated Codeunit.Run.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        NonstockItem: Record "Nonstock Item";
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literal is the key the contract guard counts as a read.
        if RequestJson.Contains('entryNo') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not FindNonstockItem(Argument, RequestJson, NonstockItem) then
            exit;
        if not CheckNotConverted(Argument, NonstockItem) then
            exit;
        if not CheckCatalogItem(Argument, NonstockItem) then
            exit;
        // A number series with no usable line passes the checks above and fails inside CreateItemFromNonstock.
        // The context is set before that run so RespondWithLastError, and the Omit Commit boundary, return the
        // documented recovery step. Omit Commit still calls Codeunit.Run without its return value, so the
        // native error propagates and the caller's transaction can roll back.
        Argument.SetErrorContext(EntryNoKeyTok, NativeExpected(), NativeNextStep());
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Nonstock Item Create Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Nonstock Item Create Proc ori", Argument) then begin
                Argument.RespondWithLastError();
                exit;
            end;
        Argument.ClearErrorContext();
    end;

    local procedure CanWriteTables(): Boolean
    var
        Item: Record Item;
        NonstockItem: Record "Nonstock Item";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemTempl: Record "Item Templ.";
        NonstockItemSetup: Record "Nonstock Item Setup";
    begin
        exit(Item.WritePermission() and NonstockItem.WritePermission() and ItemUnitOfMeasure.WritePermission() and ItemTempl.ReadPermission() and NonstockItemSetup.ReadPermission());
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
        UnknownNextStepLbl: Label 'Remove the unknown key. The only allowed key is entryNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Eini leyfði lykillinn er entryNo.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if KeyName <> EntryNoKeyTok then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure FindNonstockItem(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var NonstockItem: Record "Nonstock Item"): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        EntryNoText: Text;
        MissingErr: Label 'entryNo is required.', Comment = 'is-IS=entryNo er áskilið.';
        FormatErr: Label 'entryNo must be text.', Comment = 'is-IS=entryNo verður að vera texti.';
        FormatNextStepLbl: Label 'Send entryNo as text, for example "NS0001".', Comment = 'is-IS=Sendu entryNo sem texta, til dæmis "NS0001".';
        TooLongErr: Label 'entryNo is longer than %1 characters.', Comment = '%1 = maximum length, is-IS=entryNo er lengra en %1 stafir.';
        TooLongNextStepLbl: Label 'Send an entryNo of at most %1 characters.', Comment = '%1 = maximum length, is-IS=Sendu entryNo sem er mest %1 stafir.';
        NotFoundErr: Label 'No catalog item has Entry No. %1.', Comment = '%1 = entry no., is-IS=Engin vörulistavara hefur færslunúmerið %1.';
    begin
        if not RequestJson.Get(EntryNoKeyTok, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, EntryNoKeyTok, '', TextExpectedTok, EntryNoNextStep());
            exit(false);
        end;
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, EntryNoKeyTok, '', TextExpectedTok, FormatNextStepLbl);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, EntryNoKeyTok, CopyStr(Raw, 1, 250), TextExpectedTok, FormatNextStepLbl);
            exit(false);
        end;
        EntryNoText := Token.AsValue().AsText();
        if DelChr(EntryNoText, '<>', ' ') = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, EntryNoKeyTok, '', TextExpectedTok, EntryNoNextStep());
            exit(false);
        end;
        if StrLen(EntryNoText) > MaxStrLen(NonstockItem."Entry No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, MaxStrLen(NonstockItem."Entry No.")), EntryNoKeyTok, CopyStr(EntryNoText, 1, 250), Format(MaxStrLen(NonstockItem."Entry No."), 0, 9), StrSubstNo(TooLongNextStepLbl, MaxStrLen(NonstockItem."Entry No.")));
            exit(false);
        end;
        if not NonstockItem.Get(CopyStr(EntryNoText, 1, MaxStrLen(NonstockItem."Entry No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EntryNoText), EntryNoKeyTok, CopyStr(EntryNoText, 1, 250), TextExpectedTok, EntryNoNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure CheckNotConverted(var Argument: Record "Message Argument ori"; NonstockItem: Record "Nonstock Item"): Boolean
    var
        Item: Record Item;
        ConvertedErr: Label 'Catalog item %1 has already been turned into item %2.', Comment = '%1 = entry no., %2 = item no., is-IS=Vörulistavöru %1 hefur þegar verið breytt í vöru %2.';
        NotConvertedExpectedLbl: Label 'a catalog item without an item', Comment = 'is-IS=vörulistavara án vöru';
    begin
        if NonstockItem."Item No." = '' then
            exit(true);
        if not Item.Get(NonstockItem."Item No.") then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ConvertedErr, NonstockItem."Entry No.", NonstockItem."Item No."), EntryNoKeyTok, NonstockItem."Entry No.", NotConvertedExpectedLbl, ConvertedNextStep());
        exit(false);
    end;

    local procedure CheckCatalogItem(var Argument: Record "Message Argument ori"; NonstockItem: Record "Nonstock Item"): Boolean
    var
        ItemTempl: Record "Item Templ.";
        NonstockItemSetup: Record "Nonstock Item Setup";
        InventorySetup: Record "Inventory Setup";
        Item: Record Item;
        Predicted: Record "Nonstock Item";
        CatalogItemManagement: Codeunit "Catalog Item Management";
        FieldMissingErr: Label 'Catalog item %1 has no %2.', Comment = '%1 = entry no., %2 = field caption, is-IS=Vörulistavöru %1 vantar %2.';
        TemplateMissingErr: Label 'Item template %1 on catalog item %2 does not exist.', Comment = '%1 = template code, %2 = entry no., is-IS=Vörusniðmát %1 á vörulistavöru %2 er ekki til.';
        SetupMissingErr: Label 'Catalog Item Setup does not exist in this company.', Comment = 'is-IS=Uppsetning vörulistavara er ekki til í þessu fyrirtæki.';
        SetupNextStepLbl: Label 'Open the Catalog Item Setup page in Business Central, choose the item number format and send the call again.', Comment = 'is-IS=Opnaðu síðuna Uppsetning vörulistavara í Business Central, veldu snið vörunúmers og sendu kallið aftur.';
        NoSeriesMissingErr: Label 'Item template %1 has no number series and Inventory Setup has no Item Nos.', Comment = '%1 = template code, is-IS=Vörusniðmát %1 hefur enga númeraröð og birgðagrunnur hefur engin vörunúmer.';
        NoSeriesNextStepLbl: Label 'Set a number series on the item template or Item Nos. in Inventory Setup, and send the call again.', Comment = 'is-IS=Settu númeraröð á vörusniðmátið eða vörunúmer í birgðagrunni og sendu kallið aftur.';
        ItemExistsErr: Label 'Catalog item %1 would get item number %2, and item %2 already exists.', Comment = '%1 = entry no., %2 = item no., is-IS=Vörulistavara %1 fengi vörunúmerið %2 og vara %2 er þegar til.';
        ItemExistsNextStepLbl: Label 'Change the vendor item number or manufacturer of the catalog item, or the number format in Catalog Item Setup, so the number is free, and send the call again.', Comment = 'is-IS=Breyttu vörunúmeri lánardrottins eða framleiðanda vörulistavörunnar, eða númerasniðinu í uppsetningu vörulistavara, svo númerið sé laust, og sendu kallið aftur.';
    begin
        if NonstockItem."Vendor No." = '' then
            exit(RespondFieldMissing(Argument, NonstockItem."Entry No.", StrSubstNo(FieldMissingErr, NonstockItem."Entry No.", NonstockItem.FieldCaption("Vendor No."))));
        if NonstockItem."Vendor Item No." = '' then
            exit(RespondFieldMissing(Argument, NonstockItem."Entry No.", StrSubstNo(FieldMissingErr, NonstockItem."Entry No.", NonstockItem.FieldCaption("Vendor Item No."))));
        if NonstockItem."Unit of Measure" = '' then
            exit(RespondFieldMissing(Argument, NonstockItem."Entry No.", StrSubstNo(FieldMissingErr, NonstockItem."Entry No.", NonstockItem.FieldCaption("Unit of Measure"))));
        if NonstockItem."Item Templ. Code" = '' then
            exit(RespondFieldMissing(Argument, NonstockItem."Entry No.", StrSubstNo(FieldMissingErr, NonstockItem."Entry No.", NonstockItem.FieldCaption("Item Templ. Code"))));
        ItemTempl.SetLoadFields(Code, "No. Series");
        if not ItemTempl.Get(NonstockItem."Item Templ. Code") then
            exit(RespondFieldMissing(Argument, NonstockItem."Entry No.", StrSubstNo(TemplateMissingErr, NonstockItem."Item Templ. Code", NonstockItem."Entry No.")));
        if not NonstockItemSetup.Get() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, SetupMissingErr, EntryNoKeyTok, NonstockItem."Entry No.", '', SetupNextStepLbl);
            exit(false);
        end;
        if NonstockItemSetup."No. Format" = NonstockItemSetup."No. Format"::"Item No. Series" then begin
            if ItemTempl."No. Series" <> '' then
                exit(true);
            InventorySetup.SetLoadFields("Item Nos.");
            if InventorySetup.Get() then
                if InventorySetup."Item Nos." <> '' then
                    exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoSeriesMissingErr, ItemTempl.Code), EntryNoKeyTok, NonstockItem."Entry No.", '', NoSeriesNextStepLbl);
            exit(false);
        end;
        // Other formats derive the number from the catalog item without a number series, so the number can be checked first.
        Predicted := NonstockItem;
        CatalogItemManagement.DetermineItemNoAndItemNoSeries(Predicted);
        if Predicted."Item No." = '' then
            exit(true);
        if not Item.Get(Predicted."Item No.") then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ItemExistsErr, NonstockItem."Entry No.", Predicted."Item No."), EntryNoKeyTok, NonstockItem."Entry No.", '', ItemExistsNextStepLbl);
        exit(false);
    end;

    local procedure RespondFieldMissing(var Argument: Record "Message Argument ori"; EntryNo: Code[20]; ErrorText: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ErrorText, EntryNoKeyTok, EntryNo, '', CatalogCardNextStep());
        exit(false);
    end;

    local procedure IsNullToken(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure EntryNoNextStep(): Text
    var
        EntryNoNextStepLbl: Label 'Send entryNo with the Entry No. of an existing catalog item. Data.Records.Get on the Nonstock Item table lists them.', Comment = 'is-IS=Sendu entryNo með færslunúmeri vörulistavöru sem er til. Data.Records.Get á töflunni Nonstock Item listar þær.';
    begin
        exit(EntryNoNextStepLbl);
    end;

    local procedure ConvertedNextStep(): Text
    var
        ConvertedNextStepLbl: Label 'Use the item named in the error. To create it again, delete that item on the Item Card first; that clears the item number on the catalog item.', Comment = 'is-IS=Notaðu vöruna sem villan nefnir. Til að stofna hana aftur skaltu fyrst eyða þeirri vöru á vöruspjaldinu; það hreinsar vörunúmerið á vörulistavörunni.';
    begin
        exit(ConvertedNextStepLbl);
    end;

    local procedure CatalogCardNextStep(): Text
    var
        CatalogCardNextStepLbl: Label 'Complete the vendor, vendor item number, unit of measure and an existing item template on the Catalog Item Card in Business Central, and send the call again.', Comment = 'is-IS=Fylltu út lánardrottin, vörunúmer lánardrottins, mælieiningu og vörusniðmát sem er til á vörulistavöruspjaldinu í Business Central og sendu kallið aftur.';
    begin
        exit(CatalogCardNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set with Inventory write permissions and a Business Central permission set that can create items and change catalog items.', Comment = 'is-IS=Úthlutaðu Bifrost fullum aðgangi með skrifheimildum birgða og Business Central heimildasafni sem getur stofnað vörur og breytt vörulistavörum.';
    begin
        exit(PermissionNextStepLbl);
    end;

    local procedure NativeExpected(): Text
    var
        NativeExpectedLbl: Label 'a catalog item Business Central can turn into an item', Comment = 'is-IS=vörulistavara sem Business Central getur breytt í vöru';
    begin
        exit(NativeExpectedLbl);
    end;

    local procedure NativeNextStep(): Text
    var
        NativeNextStepLbl: Label 'Read the error text, correct the cause on the Catalog Item Card in Business Central and send the call again.', Comment = 'is-IS=Lestu villutextann, lagaðu orsökina á vörulistavöruspjaldinu í Business Central og sendu kallið aftur.';
    begin
        exit(NativeNextStepLbl);
    end;
}
