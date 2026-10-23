namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCategory.Set. Creates or updates a category and its own attribute defaults.
/// Refusals are answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10076871 "Item Category Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CodeKeyTok: Label 'code', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        DescriptionKeyTok: Label 'description', Locked = true;
        ParentKeyTok: Label 'parentCategory', Locked = true;
        DeleteKeyTok: Label 'delete', Locked = true;
        AttributesKeyTok: Label 'attributes', Locked = true;
        NameKeyTok: Label 'name', Locked = true;
        IdKeyTok: Label 'id', Locked = true;
        ValueKeyTok: Label 'value', Locked = true;
        AllowedKeysTok: Label 'code, systemId, description, parentCategory, delete, attributes', Locked = true;
        AllowedAttributeKeysTok: Label 'name, id, value', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        NumberExpectedTok: Label 'number', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        ObjectExpectedTok: Label 'object', Locked = true;
        GuidExpectedTok: Label 'guid', Locked = true;
        FalseTok: Label 'false', Locked = true;
        TrueTok: Label 'true', Locked = true;
        NotBlockedLbl: Label 'not blocked', Comment = 'is-IS=ekki lokað';
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

    /// <summary>True when the Item Category domain is on and the caller can change categories and their attribute rows.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then
            exit(false);
        exit(CanWriteTables());
    end;

    /// <summary>The table this type writes.</summary>
    /// <returns>The Item Category table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Category");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates or updates an item category and its default attributes.', Comment = 'is-IS=Stofnar eða uppfærir vöruflokk og sjálfgefna eiginleika hans.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item category, parent, attribute, default value', Comment = 'is-IS=vöruflokkur, yfirflokkur, eiginleiki, sjálfgefið gildi';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create or change an item category and the default attributes stored on it.', Comment = 'is-IS=Stofnaðu eða breyttu vöruflokki og sjálfgefnum eiginleikum sem eru vistaðir á honum.';
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
        Subject.Add('description', 'The category is named under data.code or data.systemId; subject is not read.');
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
        TargetLbl: Label 'The item category to create or update, by code or by system id.', Comment = 'is-IS=Vöruflokkurinn sem á að stofna eða uppfæra, eftir kóða eða kerfiskenni.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.code', 'text', TargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', 'The system id of an existing item category, as an alternative to data.code. Send one of them, not both.'));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        CodeLbl: Label 'Category code, at most 20 characters. A new code creates the category; an existing code updates it. Send code or systemId, not both.', Comment = 'is-IS=Kóði flokks, mest 20 stafir. Nýr kóði stofnar flokkinn; kóði sem er til uppfærir hann. Sendu code eða systemId, ekki bæði.';
        SystemIdLbl: Label 'System id (GUID) of an existing category. Send code or systemId, not both.', Comment = 'is-IS=Kerfiskenni (GUID) flokks sem er til. Sendu code eða systemId, ekki bæði.';
        DescriptionLbl: Label 'Description of the category, at most 100 characters.', Comment = 'is-IS=Lýsing flokksins, mest 100 stafir.';
        ParentLbl: Label 'Parent category code. Used when the category is created. For an existing category it must equal the current parent; moving a category is refused.', Comment = 'is-IS=Kóði yfirflokks. Notaður þegar flokkurinn er stofnaður. Fyrir flokk sem er til verður hann að vera sá sami og núverandi yfirflokkur; ekki er hægt að færa flokk.';
        DeleteLbl: Label 'true or false. true is refused: this call does not delete categories.', Comment = 'is-IS=true eða false. true er hafnað: þetta kall eyðir ekki flokkum.';
        AttributeChildren: JsonArray;
        AttributesParameter: JsonObject;
        AttributesLbl: Label 'Array of attribute defaults to store on this category. Each entry is an object with name (text) or id (number) of an existing attribute, and value (text) naming an existing value of that attribute. Dates are yyyy-mm-dd and decimals use a period.', Comment = 'is-IS=Fylki sjálfgefinna eiginleika sem á að vista á flokknum. Hver færsla er hlutur með name (texti) eða id (tala) eiginleika sem er til, og value (texti) sem nefnir gildi sem er til fyrir þann eiginleika. Dagsetningar eru á forminu yyyy-mm-dd og tugabrot nota punkt.';
    begin
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, CodeLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, DescriptionLbl));
        Parameters.Add(ContractMgt.Parameter('parentCategory', 'string', false, ParentLbl));
        Parameters.Add(ContractMgt.Parameter('delete', 'boolean', false, DeleteLbl));
        AttributeChildren.Add(ContractMgt.Parameter('name', 'string', false, 'Name of an existing attribute. Send name or id, not both.'));
        AttributeChildren.Add(ContractMgt.Parameter('id', 'integer', false, 'ID of an existing attribute. Send name or id, not both.'));
        AttributeChildren.Add(ContractMgt.Parameter('value', 'string', true, 'An existing value of that attribute, as text. Dates are yyyy-mm-dd and decimals use a period.'));
        AttributesParameter := ContractMgt.Parameter('attributes', 'array', false, AttributesLbl);
        AttributesParameter.Add('children', AttributeChildren);
        Parameters.Add(AttributesParameter);
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        AttributeField: JsonObject;
        AttributeChildren: JsonArray;
    begin
        AttributeChildren.Add(ContractMgt.ResponseField('id', 'integer', 'The ID of the item attribute.'));
        AttributeChildren.Add(ContractMgt.ResponseField('name', 'string', 'The name of the item attribute.'));
        AttributeChildren.Add(ContractMgt.ResponseField('type', 'string', 'The type of the attribute: Option, Text, Integer, Decimal or Date.'));
        AttributeChildren.Add(ContractMgt.ResponseField('value', 'string', 'The default value of the attribute for the category.'));
        AttributeChildren.Add(ContractMgt.ResponseField('inherited', 'boolean', 'True when the value comes from a parent category; false when it is set on the category itself.'));
        AttributeField := ContractMgt.ResponseField('attributes', 'array', 'Every attribute of the saved category, own values first and then values inherited from parent categories, not only the ones in the request.');
        AttributeField.Add('children', AttributeChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', 'True when the call created the category, false when it updated an existing one.'));
        Fields.Add(ContractMgt.ResponseField('code', 'string', 'The category code.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The category description after the save.'));
        Fields.Add(ContractMgt.ResponseField('parentCategory', 'string', 'The code of the parent category; empty at the top of the tree.'));
        Fields.Add(ContractMgt.ResponseField('indentation', 'integer', 'The indentation level in the category tree.'));
        Fields.Add(ContractMgt.ResponseField('presentationOrder', 'integer', 'The position of the category in the tree.'));
        Fields.Add(AttributeField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'code or systemId is missing or empty, or an attributes entry has no name or id, or no value.', Comment = 'is-IS=code eða systemId vantar eða er tómt, eða færslu í attributes vantar name eða id, eða value.';
        MissingFixLbl: Label 'Send code or systemId, and name or id plus value on each attributes entry.', Comment = 'is-IS=Sendu code eða systemId, og name eða id ásamt value í hverri færslu í attributes.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, or systemId is not a GUID.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, eða systemId er ekki GUID.';
        FormatFixLbl: Label 'Send code, systemId, description, parentCategory, name and value as text, id as a number, delete as true or false, and attributes as an array of objects.', Comment = 'is-IS=Sendu code, systemId, description, parentCategory, name og value sem texta, id sem tölu, delete sem true eða false og attributes sem fylki af hlutum.';
        UnknownWhenLbl: Label 'The request or an attributes entry contains a key this type does not read.', Comment = 'is-IS=Beiðnin eða færsla í attributes inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are code, systemId, description, parentCategory, delete and attributes; each attributes entry allows name, id and value.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru code, systemId, description, parentCategory, delete og attributes; hver færsla í attributes leyfir name, id og value.';
        NotFoundWhenLbl: Label 'The attribute or attribute value does not exist, or no category matched systemId or parentCategory.', Comment = 'is-IS=Eiginleikinn eða gildi hans er ekki til, eða enginn flokkur passaði við systemId eða parentCategory.';
        ConflictWhenLbl: Label 'code and systemId, or name and id on one attributes entry, were both sent.', Comment = 'is-IS=code og systemId, eða name og id í sömu færslu í attributes, voru bæði send.';
        ConflictFixLbl: Label 'Send code or systemId, and name or id, not both.', Comment = 'is-IS=Sendu code eða systemId, og name eða id, ekki bæði.';
        LoopWhenLbl: Label 'parentCategory would put the category inside its own subtree.', Comment = 'is-IS=parentCategory myndi setja flokkinn inn í sitt eigið undirtré.';
        TooLongWhenLbl: Label 'A text is longer than its field, or the Item Category domain is turned off.', Comment = 'is-IS=Texti er lengri en reiturinn hans, eða vöruflokkasviðið er óvirkt.';
        TooLongFixLbl: Label 'Send a code of at most 20 characters and a description of at most 100, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu kóða sem er mest 20 stafir og lýsingu sem er mest 100 stafir, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        PreconditionWhenLbl: Label 'The call asks to delete a category or to move an existing category under another parent.', Comment = 'is-IS=Kallið biður um að eyða flokki eða færa flokk sem er til undir annan yfirflokk.';
        BlockedWhenLbl: Label 'The attribute or the attribute value is blocked.', Comment = 'is-IS=Eiginleikinn eða gildi hans er lokað.';
        BlockedFixLbl: Label 'Choose an attribute and a value that are not blocked.', Comment = 'is-IS=Veldu eiginleika og gildi sem eru ekki lokuð.';
        PermissionWhenLbl: Label 'The caller cannot change item categories or their attributes.', Comment = 'is-IS=Kallandinn getur ekki breytt vöruflokkum eða eiginleikum þeirra.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, CreateAttributeNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, LoopWhenLbl, LoopNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, TooLongWhenLbl, TooLongFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionWhenLbl, DeletesNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, BlockedWhenLbl, BlockedFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refuses the save itself, after the request was checked. Nothing is saved.', 'Read the error text, correct the cause in Business Central and send the call again.'));
        exit(true);
    end;

    /// <summary>Effect chapter: writes, does not post.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('Every attribute and attribute value named in attributes already exists and is not blocked.');
        Preconditions.Add('A parent category named in parentCategory exists, and an existing category keeps the parent it has.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Creates the item category, or changes the description of an existing one, and stores the listed attribute defaults on it. A value equal to the one inherited from a parent category removes the own row of the category for that attribute. Categories are never deleted or moved. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.');
        Effect.Add('idempotent', true);
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
        GetLbl: Label 'Read the category tree and the inherited attributes instead of changing them.', Comment = 'is-IS=Lesa vöruflokkatréð og erfða eiginleika í stað þess að breyta þeim.';
        DefinitionLbl: Label 'Create the attribute and its values first when they do not exist yet.', Comment = 'is-IS=Stofna eiginleikann og gildi hans fyrst þegar þau eru ekki til.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemCategory.Get', GetLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AttributeDefinition.Create', DefinitionLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter: none.</summary>
    /// <param name="Workflow">Unused.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.AttributeDefinition.Create', 'Create the attribute and its values when they do not exist yet.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemCategory.Set', 'Create the category or change its description and its attribute defaults.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemCategory.Get', 'Read the category back, with the attributes it inherits from its parents.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create a child category with a default color', Comment = 'is-IS=Stofna undirflokk með sjálfgefnum lit';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemCategory.Set","data":{"code":"CHAIRS","description":"Chairs","parentCategory":"FURNITURE","attributes":[{"name":"Color","value":"Blue"}]}}', '{"status":"Success","created":true,"code":"CHAIRS","description":"Chairs","parentCategory":"FURNITURE","indentation":1,"presentationOrder":2,"attributes":[{"id":1,"name":"Color","type":"Option","value":"Blue","inherited":false}]}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates an item category, or updates the description of an existing one, and stores attribute defaults on that category. Each attribute and value must already exist. A value equal to the value inherited from a parent category is not stored on the category itself, and the answer lists it with inherited true. The answer is the saved category with created, its tree position and its attributes.', Comment = 'is-IS=Stofnar vöruflokk, eða uppfærir lýsingu flokks sem er til, og vistar sjálfgefna eiginleika á flokknum. Hver eiginleiki og gildi verður að vera til fyrir. Gildi sem er það sama og gildið sem erfist frá yfirflokki er ekki vistað á flokknum sjálfum og svarið sýnir það með inherited sem true. Svarið er vistaði flokkurinn með created, staðsetningu hans í trénu og eiginleikum hans.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A successful call saves the category and its attribute defaults. A refusal leaves every category and attribute unchanged. The call does not delete categories, does not move an existing category to another parent and does not post. Items already in the category keep their own attribute values; the defaults apply to items assigned to the category later. Generic data writes to item categories and their attribute rows are refused, so use this call. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Kall sem tekst vistar flokkinn og sjálfgefna eiginleika hans. Höfnun skilur alla flokka og eiginleika eftir óbreytta. Kallið eyðir ekki flokkum, færir ekki flokk sem er til undir annan yfirflokk og bókar ekki. Vörur sem eru þegar í flokknum halda sínum eigin eiginleikagildum; sjálfgefnu gildin gilda fyrir vörur sem eru settar í flokkinn síðar. Almennum gagnaskrifum í vöruflokka og eiginleikalínur þeirra er hafnað, svo notaðu þetta kall. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';
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

    /// <summary>Runs Inventory.ItemCategory.Set. Validates the whole request, then writes in an isolated Codeunit.Run.</summary>
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
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('description') then;
        if RequestJson.Contains('parentCategory') then;
        if RequestJson.Contains('delete') then;
        if RequestJson.Contains('attributes') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item Category Set Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item Category Set Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure CanWriteTables(): Boolean
    var
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
    begin
        exit(ItemCategory.WritePermission() and Mapping.WritePermission() and ItemAttribute.ReadPermission() and ItemAttributeValue.ReadPermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        DomainDisabledErr: Label 'The Item Category domain is turned off for this company.', Comment = 'is-IS=Vöruflokkasviðið er óvirkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á sviðinu á síðunni Uppsetning birgða.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanWriteTables()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStep());
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are code, systemId, description, parentCategory, delete and attributes.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru code, systemId, description, parentCategory, delete og attributes.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [CodeKeyTok, SystemIdKeyTok, DescriptionKeyTok, ParentKeyTok, DeleteKeyTok, AttributesKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        ItemCategory: Record "Item Category";
        CategoryCode: Code[20];
        CurrentParent: Code[20];
        CategoryExists: Boolean;
        DeleteErr: Label 'Deleting a category is not part of this call.', Comment = 'is-IS=Eyðing flokks er ekki hluti af þessu kalli.';
        ConflictErr: Label 'code and systemId were both sent.', Comment = 'is-IS=code og systemId voru bæði send.';
        ConflictNextStepLbl: Label 'Send code or systemId, not both.', Comment = 'is-IS=Sendu code eða systemId, ekki bæði.';
        MissingErr: Label 'code or systemId is required.', Comment = 'is-IS=code eða systemId er áskilið.';
        MissingNextStepLbl: Label 'Send code to create or update a category, or systemId to update an existing one.', Comment = 'is-IS=Sendu code til að stofna eða uppfæra flokk, eða systemId til að uppfæra flokk sem er til.';
    begin
        if not ValidateShapes(Argument, RequestJson) then
            exit(false);
        if ReadBoolean(RequestJson, DeleteKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, DeleteErr, DeleteKeyTok, TrueTok, FalseTok, DeletesNextStep());
            exit(false);
        end;
        if RequestJson.Contains(CodeKeyTok) and RequestJson.Contains(SystemIdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, CodeKeyTok, '', SystemIdKeyTok, ConflictNextStepLbl);
            exit(false);
        end;
        if (not RequestJson.Contains(CodeKeyTok)) and (not RequestJson.Contains(SystemIdKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CodeKeyTok, '', CodeKeyTok, MissingNextStepLbl);
            exit(false);
        end;
        if not ReadCategoryIdentity(Argument, RequestJson, ItemCategory, CategoryCode, CategoryExists) then
            exit(false);
        if CategoryExists then
            CurrentParent := ItemCategory."Parent Category";
        if not ValidateParent(Argument, RequestJson, CategoryCode, CategoryExists, CurrentParent) then
            exit(false);
        exit(ValidateAttributes(Argument, RequestJson));
    end;

    local procedure ValidateShapes(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        ItemCategory: Record "Item Category";
        CodeText: Text;
        DescriptionText: Text;
        ParentText: Text;
        CodeEmptyErr: Label 'code is empty.', Comment = 'is-IS=code er tómt.';
        CodeEmptyNextStepLbl: Label 'Send a category code.', Comment = 'is-IS=Sendu kóða flokks.';
    begin
        if RequestJson.Contains(CodeKeyTok) then begin
            if not RequireText(Argument, RequestJson, CodeKeyTok) then
                exit(false);
            CodeText := ReadText(RequestJson, CodeKeyTok);
            if CodeText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, CodeEmptyErr, CodeKeyTok, '', CodeKeyTok, CodeEmptyNextStepLbl);
                exit(false);
            end;
            if not CheckLength(Argument, CodeKeyTok, CodeText, MaxStrLen(ItemCategory.Code)) then
                exit(false);
        end;
        if RequestJson.Contains(SystemIdKeyTok) then
            if not RequireGuid(Argument, RequestJson, SystemIdKeyTok) then
                exit(false);
        if RequestJson.Contains(DescriptionKeyTok) then begin
            if not RequireText(Argument, RequestJson, DescriptionKeyTok) then
                exit(false);
            DescriptionText := ReadText(RequestJson, DescriptionKeyTok);
            if not CheckLength(Argument, DescriptionKeyTok, DescriptionText, MaxStrLen(ItemCategory.Description)) then
                exit(false);
        end;
        if RequestJson.Contains(ParentKeyTok) then begin
            if not RequireText(Argument, RequestJson, ParentKeyTok) then
                exit(false);
            ParentText := ReadText(RequestJson, ParentKeyTok);
            if not CheckLength(Argument, ParentKeyTok, ParentText, MaxStrLen(ItemCategory."Parent Category")) then
                exit(false);
        end;
        if RequestJson.Contains(DeleteKeyTok) then
            if not RequireBoolean(Argument, RequestJson, DeleteKeyTok) then
                exit(false);
        if RequestJson.Contains(AttributesKeyTok) then
            if not RequireArray(Argument, RequestJson, AttributesKeyTok) then
                exit(false);
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

    local procedure ReadCategoryIdentity(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemCategory: Record "Item Category"; var CategoryCode: Code[20]; var CategoryExists: Boolean): Boolean
    var
        CategoryId: Guid;
        NotFoundErr: Label 'No item category matched systemId.', Comment = 'is-IS=Enginn vöruflokkur passaði við systemId.';
        NotFoundNextStepLbl: Label 'Check the system id, or send code to create a new category.', Comment = 'is-IS=Athugaðu kerfiskennið, eða sendu code til að stofna nýjan flokk.';
    begin
        CategoryExists := false;
        CategoryCode := '';
        ItemCategory.SetLoadFields(Code, "Parent Category", Description);
        if RequestJson.Contains(SystemIdKeyTok) then begin
            if not Evaluate(CategoryId, ReadText(RequestJson, SystemIdKeyTok)) then
                exit(false);
            if not ItemCategory.GetBySystemId(CategoryId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, SystemIdKeyTok, Format(CategoryId, 0, 4), SystemIdKeyTok, NotFoundNextStepLbl);
                exit(false);
            end;
            CategoryCode := ItemCategory.Code;
            CategoryExists := true;
            exit(true);
        end;
        CategoryCode := CopyStr(ReadText(RequestJson, CodeKeyTok), 1, MaxStrLen(ItemCategory.Code));
        CategoryExists := ItemCategory.Get(CategoryCode);
        exit(true);
    end;

    local procedure ValidateParent(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; CategoryCode: Code[20]; CategoryExists: Boolean; CurrentParent: Code[20]): Boolean
    var
        ParentCategory: Record "Item Category";
        ParentCode: Code[20];
        ParentMissingErr: Label 'The parent category does not exist.', Comment = 'is-IS=Yfirflokkurinn er ekki til.';
        ParentMissingNextStepLbl: Label 'Check the parent category code, or create the parent category first.', Comment = 'is-IS=Athugaðu kóða yfirflokksins, eða stofnaðu yfirflokkinn fyrst.';
        LoopErr: Label 'The parent would put this category inside its own subtree.', Comment = 'is-IS=Yfirflokkurinn myndi setja þennan flokk inn í sitt eigið undirtré.';
        ReparentErr: Label 'Moving an existing category to another parent is not part of this call.', Comment = 'is-IS=Að færa flokk sem er til undir annan yfirflokk er ekki hluti af þessu kalli.';
    begin
        if not RequestJson.Contains(ParentKeyTok) then
            exit(true);
        ParentCode := CopyStr(ReadText(RequestJson, ParentKeyTok), 1, MaxStrLen(ParentCategory.Code));
        if WouldLoop(CategoryCode, ParentCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, LoopErr, ParentKeyTok, ParentCode, CurrentParent, LoopNextStep());
            exit(false);
        end;
        if ParentCode <> '' then begin
            ParentCategory.SetLoadFields(Code);
            if not ParentCategory.Get(ParentCode) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, ParentMissingErr, ParentKeyTok, ParentCode, ParentKeyTok, ParentMissingNextStepLbl);
                exit(false);
            end;
        end;
        if CategoryExists and (ParentCode <> CurrentParent) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ReparentErr, ParentKeyTok, ParentCode, CurrentParent, DeletesNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure WouldLoop(CategoryCode: Code[20]; ParentCode: Code[20]): Boolean
    var
        ItemCategory: Record "Item Category";
        Walk: Code[20];
        Visited: List of [Code[20]];
    begin
        if ParentCode = '' then
            exit(false);
        if ParentCode = CategoryCode then
            exit(true);
        Walk := ParentCode;
        ItemCategory.SetLoadFields(Code, "Parent Category");
        while ItemCategory.Get(Walk) do begin
            if ItemCategory.Code = CategoryCode then
                exit(true);
            if Visited.Contains(Walk) then
                exit(true);
            Visited.Add(Walk);
            if ItemCategory."Parent Category" = '' then
                exit(false);
            Walk := ItemCategory."Parent Category";
        end;
        exit(false);
    end;

    local procedure ValidateAttributes(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Attributes: JsonArray;
        AttributeToken: JsonToken;
        AttributeJson: JsonObject;
        Index: Integer;
        NotObjectErr: Label 'Each attributes entry must be an object.', Comment = 'is-IS=Hver færsla í attributes verður að vera hlutur.';
        NotObjectNextStepLbl: Label 'Send each attributes entry as an object with name or id, and value.', Comment = 'is-IS=Sendu hverja færslu í attributes sem hlut með name eða id, og value.';
    begin
        if not ReadArray(RequestJson, AttributesKeyTok, Attributes) then
            exit(true);
        for Index := 0 to Attributes.Count() - 1 do begin
            Attributes.Get(Index, AttributeToken);
            if not AttributeToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, NotObjectErr, AttributesKeyTok, Format(Index, 0, 9), ObjectExpectedTok, NotObjectNextStepLbl);
                exit(false);
            end;
            AttributeJson := AttributeToken.AsObject();
            if not ValidateOneAttribute(Argument, AttributeJson) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateOneAttribute(var Argument: Record "Message Argument ori"; AttributeJson: JsonObject): Boolean
    var
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        KeyName: Text;
        UnknownKeyErr: Label 'The attributes entry contains an unknown key.', Comment = 'is-IS=Færslan í attributes inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Each attributes entry allows name, id and value.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Hver færsla í attributes leyfir name, id og value.';
        ConflictErr: Label 'name and id were both sent on one attributes entry.', Comment = 'is-IS=name og id voru bæði send í sömu færslu í attributes.';
        ConflictNextStepLbl: Label 'Send name or id, not both.', Comment = 'is-IS=Sendu name eða id, ekki bæði.';
        IdentityMissingErr: Label 'An attributes entry has neither name nor id.', Comment = 'is-IS=Færslu í attributes vantar bæði name og id.';
        ValueMissingErr: Label 'An attributes entry has no value.', Comment = 'is-IS=Færslu í attributes vantar value.';
        ValueMissingNextStepLbl: Label 'Send the attribute value as text.', Comment = 'is-IS=Sendu gildi eiginleikans sem texta.';
        AttributeBlockedErr: Label 'The attribute is blocked.', Comment = 'is-IS=Eiginleikinn er lokaður.';
        AttributeBlockedNextStepLbl: Label 'Choose an attribute that is not blocked.', Comment = 'is-IS=Veldu eiginleika sem er ekki lokaður.';
        ValueBlockedErr: Label 'The attribute value is blocked.', Comment = 'is-IS=Gildi eiginleikans er lokað.';
        ValueBlockedNextStepLbl: Label 'Choose an attribute value that is not blocked.', Comment = 'is-IS=Veldu gildi eiginleika sem er ekki lokað.';
    begin
        // String literals are the element keys of attributes; the contract describes them on attributes.
        if AttributeJson.Contains('name') then;
        if AttributeJson.Contains('id') then;
        if AttributeJson.Contains('value') then;
        foreach KeyName in AttributeJson.Keys() do
            if not (KeyName in [NameKeyTok, IdKeyTok, ValueKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedAttributeKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        if AttributeJson.Contains(NameKeyTok) and AttributeJson.Contains(IdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, NameKeyTok, '', IdKeyTok, ConflictNextStepLbl);
            exit(false);
        end;
        if (not AttributeJson.Contains(NameKeyTok)) and (not AttributeJson.Contains(IdKeyTok)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, IdentityMissingErr, NameKeyTok, '', NameKeyTok, AttributeIdentityNextStep());
            exit(false);
        end;
        if not AttributeJson.Contains(ValueKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, ValueMissingErr, ValueKeyTok, '', ValueKeyTok, ValueMissingNextStepLbl);
            exit(false);
        end;
        if not RequireText(Argument, AttributeJson, ValueKeyTok) then
            exit(false);
        if not FindAttribute(Argument, AttributeJson, ItemAttribute) then
            exit(false);
        if ItemAttribute.Blocked then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, AttributeBlockedErr, NameKeyTok, ItemAttribute.Name, NotBlockedLbl, AttributeBlockedNextStepLbl);
            exit(false);
        end;
        if not FindValue(Argument, ItemAttribute, ReadText(AttributeJson, ValueKeyTok), ItemAttributeValue) then
            exit(false);
        if ItemAttributeValue.Blocked then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ValueBlockedErr, ValueKeyTok, ItemAttributeValue.Value, NotBlockedLbl, ValueBlockedNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure FindAttribute(var Argument: Record "Message Argument ori"; AttributeJson: JsonObject; var ItemAttribute: Record "Item Attribute"): Boolean
    var
        AttributeId: Integer;
        AttributeName: Text;
        MissingErr: Label 'The attribute does not exist.', Comment = 'is-IS=Eiginleikinn er ekki til.';
        NameEmptyErr: Label 'The attribute name is empty.', Comment = 'is-IS=Nafn eiginleikans er tómt.';
    begin
        ItemAttribute.SetLoadFields(ID, Name, Type, Blocked);
        if AttributeJson.Contains(IdKeyTok) then begin
            if not RequireInteger(Argument, AttributeJson, IdKeyTok) then
                exit(false);
            AttributeId := ReadInteger(AttributeJson, IdKeyTok);
            if not ItemAttribute.Get(AttributeId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, IdKeyTok, Format(AttributeId, 0, 9), IdKeyTok, CreateAttributeNextStep());
                exit(false);
            end;
            exit(true);
        end;
        if not RequireText(Argument, AttributeJson, NameKeyTok) then
            exit(false);
        AttributeName := ReadText(AttributeJson, NameKeyTok);
        if AttributeName = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, NameEmptyErr, NameKeyTok, '', NameKeyTok, AttributeIdentityNextStep());
            exit(false);
        end;
        ItemAttribute.SetRange(Name, CopyStr(AttributeName, 1, MaxStrLen(ItemAttribute.Name)));
        if not ItemAttribute.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, NameKeyTok, CopyStr(AttributeName, 1, 250), NameKeyTok, CreateAttributeNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure FindValue(var Argument: Record "Message Argument ori"; ItemAttribute: Record "Item Attribute"; ValueText: Text; var ItemAttributeValue: Record "Item Attribute Value"): Boolean
    var
        SetProc: Codeunit "Item Category Set Proc ori";
        MissingErr: Label 'The attribute value does not exist.', Comment = 'is-IS=Gildi eiginleikans er ekki til.';
    begin
        if SetProc.FindAttributeValue(ItemAttribute, ValueText, ItemAttributeValue) then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, ValueKeyTok, CopyStr(ValueText, 1, 250), ValueKeyTok, CreateAttributeNextStep());
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

    local procedure RequireInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Integer;
        FormatErr: Label '%1 must be a whole number.', Comment = '%1 = key, is-IS=%1 verður að vera heiltala.';
        FormatNextStepLbl: Label 'Send %1 as a whole number.', Comment = '%1 = key, is-IS=Sendu %1 sem heiltölu.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (not Evaluate(Probe, Raw, 9)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), NumberExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
        FormatNextStepLbl: Label 'Send %1 as true or false.', Comment = '%1 = key, is-IS=Sendu %1 sem true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if (Raw <> TrueTok) and (Raw <> FalseTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireArray(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        FormatErr: Label '%1 must be an array.', Comment = '%1 = key, is-IS=%1 verður að vera fylki.';
        FormatNextStepLbl: Label 'Send %1 as an array of objects.', Comment = '%1 = key, is-IS=Sendu %1 sem fylki af hlutum.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', ArrayExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireGuid(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        CategoryId: Guid;
        SystemIdText: Text;
        EmptyErr: Label 'systemId is empty.', Comment = 'is-IS=systemId er tómt.';
        EmptyNextStepLbl: Label 'Send the system id of an existing category, or send code instead.', Comment = 'is-IS=Sendu kerfiskenni flokks sem er til, eða sendu code í staðinn.';
        NotGuidErr: Label 'systemId is not a GUID.', Comment = 'is-IS=systemId er ekki GUID.';
        NotGuidNextStepLbl: Label 'Send systemId as a GUID, for example 00000000-0000-0000-0000-000000000001.', Comment = 'is-IS=Sendu systemId sem GUID, til dæmis 00000000-0000-0000-0000-000000000001.';
    begin
        if not RequireText(Argument, RequestJson, KeyName) then
            exit(false);
        SystemIdText := ReadText(RequestJson, KeyName);
        if SystemIdText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, EmptyErr, SystemIdKeyTok, '', SystemIdKeyTok, EmptyNextStepLbl);
            exit(false);
        end;
        if not Evaluate(CategoryId, SystemIdText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, NotGuidErr, SystemIdKeyTok, CopyStr(SystemIdText, 1, 250), GuidExpectedTok, NotGuidNextStepLbl);
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

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadBoolean(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure ReadArray(RequestJson: JsonObject; KeyName: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Result := Token.AsArray();
        exit(true);
    end;

    local procedure AttributeIdentityNextStep(): Text
    var
        IdentityNextStepLbl: Label 'Send the attribute name or id.', Comment = 'is-IS=Sendu nafn eða id eiginleikans.';
    begin
        exit(IdentityNextStepLbl);
    end;

    local procedure CreateAttributeNextStep(): Text
    var
        CreateNextStepLbl: Label 'Create the attribute with Inventory.AttributeDefinition.Create first.', Comment = 'is-IS=Stofnaðu eiginleikann fyrst með Inventory.AttributeDefinition.Create.';
    begin
        exit(CreateNextStepLbl);
    end;

    local procedure LoopNextStep(): Text
    var
        LoopNextStepLbl: Label 'Choose a parent outside this category''s subtree.', Comment = 'is-IS=Veldu yfirflokk utan undirtrés þessa flokks.';
    begin
        exit(LoopNextStepLbl);
    end;

    local procedure DeletesNextStep(): Text
    var
        DeletesNextStepLbl: Label 'Use the BC page for deletes.', Comment = 'is-IS=Notaðu síðuna í BC til að eyða.';
    begin
        exit(DeletesNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.', Comment = 'is-IS=Úthlutaðu BIFROST Full ori (með viðbótinni BIFROST InvWrite ori) og Business Central heimildasafni sem getur breytt þessum töflum.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
