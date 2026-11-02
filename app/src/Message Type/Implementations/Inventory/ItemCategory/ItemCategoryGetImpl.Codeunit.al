namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCategory.Get. Returns the category tree and, when asked, each category's attributes.
/// Read-only: checks read permission and never changes a category or an attribute.
/// </summary>
codeunit 10076870 "Item Category Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CodeKeyTok: Label 'code', Locked = true;
        SystemIdKeyTok: Label 'systemId', Locked = true;
        IncludeAttributesKeyTok: Label 'includeAttributes', Locked = true;
        AllowedKeysTok: Label 'code, systemId, includeAttributes', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        GuidExpectedTok: Label 'guid', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;

    /// <summary>True when the Item Category domain is on and the caller can read categories and attributes.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then
            exit(false);
        exit(CanReadTables());
    end;

    /// <summary>The table this type reads.</summary>
    /// <returns>The Item Category table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Category");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads item categories and their default attributes.', Comment = 'is-IS=Les vöruflokka og sjálfgefna eiginleika þeirra.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item category, parent, attribute, inherited', Comment = 'is-IS=vöruflokkur, yfirflokkur, eiginleiki, erft';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Show the item category tree and the default attributes on each category.', Comment = 'is-IS=Sýndu vöruflokkatréð og sjálfgefna eiginleika hvers flokks.';
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
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Target chapter.</summary>
    /// <param name="Target">Receives the target entries.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetLbl: Label 'The item category to read. Omit code and systemId to read every category.', Comment = 'is-IS=Vöruflokkurinn sem á að lesa. Slepptu code og systemId til að lesa alla flokka.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.code', 'text', TargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId', 'guid', 'The system id of the item category, as an alternative to data.code. Send one of them, not both.'));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        CodeLbl: Label 'Category code, at most 20 characters. Omit both code and systemId to return every category. Send code or systemId, not both.', Comment = 'is-IS=Kóði flokks, mest 20 stafir. Slepptu bæði code og systemId til að fá alla flokka. Sendu code eða systemId, ekki bæði.';
        SystemIdLbl: Label 'System id (GUID) of the category. Send code or systemId, not both.', Comment = 'is-IS=Kerfiskenni (GUID) flokksins. Sendu code eða systemId, ekki bæði.';
        IncludeAttributesLbl: Label 'true or false. When true, each category lists its attributes with id, name, type, value and inherited. Defaults to true.', Comment = 'is-IS=true eða false. Þegar true er sent fylgja hverjum flokki eiginleikar hans með id, name, type, value og inherited. Sjálfgefið er true.';
    begin
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, CodeLbl));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, SystemIdLbl));
        Parameters.Add(ContractMgt.Parameter('includeAttributes', 'boolean', false, IncludeAttributesLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        CategoryField: JsonObject;
        AttributeField: JsonObject;
        CategoryChildren: JsonArray;
        AttributeChildren: JsonArray;
    begin
        AttributeChildren.Add(ContractMgt.ResponseField('id', 'integer', 'The ID of the item attribute.'));
        AttributeChildren.Add(ContractMgt.ResponseField('name', 'string', 'The name of the item attribute.'));
        AttributeChildren.Add(ContractMgt.ResponseField('type', 'string', 'The type of the attribute: Option, Text, Integer, Decimal or Date.'));
        AttributeChildren.Add(ContractMgt.ResponseField('value', 'string', 'The default value of the attribute for the category.'));
        AttributeChildren.Add(ContractMgt.ResponseField('inherited', 'boolean', 'True when the value comes from a parent category; false when it is set on the category itself.'));
        AttributeField := ContractMgt.ResponseField('attributes', 'array', 'The attributes of the category, own values first and then values inherited from parent categories. Present only when includeAttributes is true, which is the default.');
        AttributeField.Add('children', AttributeChildren);
        CategoryChildren.Add(ContractMgt.ResponseField('code', 'string', 'The category code.'));
        CategoryChildren.Add(ContractMgt.ResponseField('description', 'string', 'The category description.'));
        CategoryChildren.Add(ContractMgt.ResponseField('parentCategory', 'string', 'The code of the parent category; empty at the top of the tree.'));
        CategoryChildren.Add(ContractMgt.ResponseField('indentation', 'integer', 'The indentation level in the category tree.'));
        CategoryChildren.Add(ContractMgt.ResponseField('presentationOrder', 'integer', 'The position of the category in the tree.'));
        CategoryChildren.Add(AttributeField);
        CategoryField := ContractMgt.ResponseField('categories', 'array', 'The categories read: one when code or systemId was sent, otherwise every category in presentation order.');
        CategoryField.Add('children', CategoryChildren);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(CategoryField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'code or systemId was sent empty.', Comment = 'is-IS=code eða systemId var sent tómt.';
        MissingFixLbl: Label 'Send a non-empty code or systemId, or omit both to read every category.', Comment = 'is-IS=Sendu code eða systemId sem er ekki tómt, eða slepptu báðum til að lesa alla flokka.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, or systemId is not a GUID.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, eða systemId er ekki GUID.';
        FormatFixLbl: Label 'Send code as text, systemId as a GUID in text, and includeAttributes as true or false.', Comment = 'is-IS=Sendu code sem texta, systemId sem GUID í texta og includeAttributes sem true eða false.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        NotFoundWhenLbl: Label 'No item category matched code or systemId.', Comment = 'is-IS=Enginn vöruflokkur passaði við code eða systemId.';
        ConflictWhenLbl: Label 'code and systemId were both sent.', Comment = 'is-IS=code og systemId voru bæði send.';
        InvalidWhenLbl: Label 'code is longer than 20 characters, or the Item Category domain is turned off.', Comment = 'is-IS=code er lengra en 20 stafir, eða vöruflokkasviðið er óvirkt.';
        InvalidFixLbl: Label 'Send a code of at most 20 characters, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu kóða sem er mest 20 stafir, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        PermissionWhenLbl: Label 'The caller cannot read item categories or item attributes.', Comment = 'is-IS=Kallandinn getur ekki lesið vöruflokka eða vörueiginleika.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        exit(true);
    end;

    /// <summary>Effect chapter: this type does not write.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Nothing. The call only reads item categories and, when includeAttributes is true, their attribute values.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'the Bifrost "Read-Only" permission set');
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
        SetLbl: Label 'Create a category, or change its description or default attributes.', Comment = 'is-IS=Stofna flokk, eða breyta lýsingu hans eða sjálfgefnum eiginleikum.';
        AttributeGetLbl: Label 'Read the attribute values stored on one item instead of on a category.', Comment = 'is-IS=Lesa eiginleikagildi sem eru vistuð á einni vöru í stað flokks.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemCategory.Set', SetLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Get', AttributeGetLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter: none.</summary>
    /// <param name="Workflow">Unused.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Read one category with its attributes', Comment = 'is-IS=Lesa einn flokk með eiginleikum hans';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemCategory.Get","data":{"code":"CHAIRS","includeAttributes":true}}', '{"status":"Success","categories":[{"code":"CHAIRS","description":"Chairs","parentCategory":"FURNITURE","indentation":1,"presentationOrder":2,"attributes":[{"id":1,"name":"Color","type":"Option","value":"Blue","inherited":true}]}]}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads item categories with code, description, parent category, indentation and presentation order. Send code or systemId to read one category, or neither to read the whole tree in presentation order. With includeAttributes true, each category lists its attributes with id, name, type, default value and whether the value is inherited from a parent category.', Comment = 'is-IS=Les vöruflokka með kóða, lýsingu, yfirflokki, inndrætti og birtingarröð. Sendu code eða systemId til að lesa einn flokk, eða hvorugt til að lesa allt tréð í birtingarröð. Með includeAttributes sem true fylgja hverjum flokki eiginleikar hans með id, nafni, gerð, sjálfgefnu gildi og upplýsingum um hvort gildið erfist frá yfirflokki.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'This call only reads. inherited is true when the value comes from a parent category; a value set on the category itself is listed with inherited false and hides the parent value. The caller needs read access to item categories and item attributes.', Comment = 'is-IS=Þetta kall les eingöngu. inherited er true þegar gildið kemur frá yfirflokki; gildi sem er sett á flokkinn sjálfan birtist með inherited false og kemur í stað gildis yfirflokksins. Kallandinn þarf lesaðgang að vöruflokkum og vörueiginleikum.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Message direction.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Runs Inventory.ItemCategory.Get.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        CategoryCode: Code[20];
        CategoryId: Guid;
        IncludeAttributes: Boolean;
        SelectAll: Boolean;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('includeAttributes') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson, CategoryCode, CategoryId, IncludeAttributes, SelectAll) then
            exit;
        WriteResponse(Argument, CategoryCode, CategoryId, IncludeAttributes, SelectAll);
    end;

    /// <summary>Builds the JSON object for one category, shared with Inventory.ItemCategory.Set.</summary>
    /// <param name="ItemCategory">The category; Code, Description, Parent Category, Indentation and Presentation Order must be loaded.</param>
    /// <param name="IncludeAttributes">True to add the attributes array.</param>
    /// <returns>The category JSON object.</returns>
    procedure BuildCategoryJson(ItemCategory: Record "Item Category"; IncludeAttributes: Boolean) Result: JsonObject
    var
        Attributes: JsonArray;
    begin
        Result.Add('code', ItemCategory.Code);
        Result.Add('description', ItemCategory.Description);
        Result.Add('parentCategory', ItemCategory."Parent Category");
        Result.Add('indentation', ItemCategory.Indentation);
        Result.Add('presentationOrder', ItemCategory."Presentation Order");
        if not IncludeAttributes then
            exit;
        Attributes := CollectAttributes(ItemCategory.Code);
        Result.Add('attributes', Attributes);
    end;

    local procedure CanReadTables(): Boolean
    var
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
    begin
        exit(ItemCategory.ReadPermission() and Mapping.ReadPermission() and ItemAttribute.ReadPermission() and ItemAttributeValue.ReadPermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        DomainDisabledErr: Label 'The Item Category domain is turned off for this company.', Comment = 'is-IS=Vöruflokkasviðið er óvirkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Ask an administrator with the Inv. Posting Gate permission set to turn the domain on from the Inventory Setup page. Data.Records.Set cannot change this setup.', Comment = 'is-IS=Biddu kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á sviðinu á síðunni Uppsetning birgða. Data.Records.Set getur ekki breytt þessari uppsetningu.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanReadTables()) then begin
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
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [CodeKeyTok, SystemIdKeyTok, IncludeAttributesKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStep());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var CategoryCode: Code[20]; var CategoryId: Guid; var IncludeAttributes: Boolean; var SelectAll: Boolean): Boolean
    var
        ItemCategory: Record "Item Category";
        CodeText: Text;
        SystemIdText: Text;
        ConflictErr: Label 'code and systemId were both sent.', Comment = 'is-IS=code og systemId voru bæði send.';
        CodeEmptyErr: Label 'code is empty.', Comment = 'is-IS=code er tómt.';
        CodeEmptyNextStepLbl: Label 'Send a category code, or omit code to read every category.', Comment = 'is-IS=Sendu kóða flokks, eða slepptu code til að lesa alla flokka.';
        TooLongErr: Label 'code is longer than %1 characters.', Comment = '%1 = maximum length, is-IS=code er lengra en %1 stafir.';
        TooLongNextStepLbl: Label 'Send a category code of at most %1 characters.', Comment = '%1 = maximum length, is-IS=Sendu kóða flokks sem er mest %1 stafir.';
        SystemIdEmptyErr: Label 'systemId is empty.', Comment = 'is-IS=systemId er tómt.';
        SystemIdEmptyNextStepLbl: Label 'Send the system id of a category, or omit systemId.', Comment = 'is-IS=Sendu kerfiskenni flokks, eða slepptu systemId.';
        NotGuidErr: Label 'systemId is not a GUID.', Comment = 'is-IS=systemId er ekki GUID.';
        NotGuidNextStepLbl: Label 'Send systemId as a GUID, for example 00000000-0000-0000-0000-000000000001.', Comment = 'is-IS=Sendu systemId sem GUID, til dæmis 00000000-0000-0000-0000-000000000001.';
    begin
        Clear(CategoryId);
        CategoryCode := '';
        SelectAll := false;
        IncludeAttributes := true;
        if RequestJson.Contains(CodeKeyTok) and RequestJson.Contains(SystemIdKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, CodeKeyTok, '', SystemIdKeyTok, ConflictNextStep());
            exit(false);
        end;
        if RequestJson.Contains(IncludeAttributesKeyTok) then begin
            if not RequireBoolean(Argument, RequestJson, IncludeAttributesKeyTok) then
                exit(false);
            IncludeAttributes := ReadBoolean(RequestJson, IncludeAttributesKeyTok);
        end;
        if RequestJson.Contains(CodeKeyTok) then begin
            if not RequireText(Argument, RequestJson, CodeKeyTok) then
                exit(false);
            CodeText := ReadText(RequestJson, CodeKeyTok);
            if CodeText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, CodeEmptyErr, CodeKeyTok, '', CodeKeyTok, CodeEmptyNextStepLbl);
                exit(false);
            end;
            if StrLen(CodeText) > MaxStrLen(ItemCategory.Code) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, MaxStrLen(ItemCategory.Code)), CodeKeyTok, CopyStr(CodeText, 1, 250), Format(MaxStrLen(ItemCategory.Code), 0, 9), StrSubstNo(TooLongNextStepLbl, MaxStrLen(ItemCategory.Code)));
                exit(false);
            end;
            CategoryCode := CopyStr(CodeText, 1, MaxStrLen(ItemCategory.Code));
            exit(true);
        end;
        if RequestJson.Contains(SystemIdKeyTok) then begin
            if not RequireText(Argument, RequestJson, SystemIdKeyTok) then
                exit(false);
            SystemIdText := ReadText(RequestJson, SystemIdKeyTok);
            if SystemIdText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, SystemIdEmptyErr, SystemIdKeyTok, '', SystemIdKeyTok, SystemIdEmptyNextStepLbl);
                exit(false);
            end;
            if not Evaluate(CategoryId, SystemIdText) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, NotGuidErr, SystemIdKeyTok, CopyStr(SystemIdText, 1, 250), GuidExpectedTok, NotGuidNextStepLbl);
                exit(false);
            end;
            exit(true);
        end;
        SelectAll := true;
        exit(true);
    end;

    local procedure WriteResponse(var Argument: Record "Message Argument ori"; CategoryCode: Code[20]; CategoryId: Guid; IncludeAttributes: Boolean; SelectAll: Boolean)
    var
        ItemCategory: Record "Item Category";
        ResponseJson: JsonObject;
        Categories: JsonArray;
        NotFoundErr: Label 'No item category matched.', Comment = 'is-IS=Enginn vöruflokkur fannst.';
    begin
        ItemCategory.SetLoadFields(Code, Description, "Parent Category", Indentation, "Presentation Order");
        if SelectAll then begin
            ItemCategory.SetCurrentKey("Presentation Order");
            if ItemCategory.FindSet() then
                repeat
                    Categories.Add(BuildCategoryJson(ItemCategory, IncludeAttributes));
                until ItemCategory.Next() = 0;
        end else begin
            if CategoryCode <> '' then begin
                if not ItemCategory.Get(CategoryCode) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, CodeKeyTok, CategoryCode, CodeKeyTok, NotFoundNextStep());
                    exit;
                end;
            end else
                if not ItemCategory.GetBySystemId(CategoryId) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, SystemIdKeyTok, Format(CategoryId, 0, 4), SystemIdKeyTok, NotFoundNextStep());
                    exit;
                end;
            Categories.Add(BuildCategoryJson(ItemCategory, IncludeAttributes));
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('categories', Categories);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CollectAttributes(CategoryCode: Code[20]) Attributes: JsonArray
    var
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        AttributeResolve: Codeunit "Item Attribute Resolve ori";
        Seen: List of [Integer];
        Visited: List of [Code[20]];
        Entry: JsonObject;
        CurrentCode: Code[20];
    begin
        CurrentCode := CategoryCode;
        ItemCategory.SetLoadFields(Code, "Parent Category");
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        ItemAttribute.SetLoadFields(ID, Name, Type);
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value);
        Mapping.SetRange("Table ID", Database::"Item Category");
        repeat
            if Visited.Contains(CurrentCode) then
                exit;
            Visited.Add(CurrentCode);
            if not ItemCategory.Get(CurrentCode) then
                exit;
            Mapping.SetRange("No.", CurrentCode);
            if Mapping.FindSet() then
                repeat
                    if not Seen.Contains(Mapping."Item Attribute ID") then begin
                        Seen.Add(Mapping."Item Attribute ID");
                        if ItemAttribute.Get(Mapping."Item Attribute ID") then
                            if ItemAttributeValue.Get(Mapping."Item Attribute ID", Mapping."Item Attribute Value ID") then begin
                                Clear(Entry);
                                Entry.Add('id', ItemAttribute.ID);
                                Entry.Add('name', ItemAttribute.Name);
                                Entry.Add('type', AttributeResolve.TypeName(ItemAttribute));
                                Entry.Add('value', ItemAttributeValue.Value);
                                Entry.Add('inherited', CurrentCode <> CategoryCode);
                                Attributes.Add(Entry);
                            end;
                    end;
                until Mapping.Next() = 0;
            CurrentCode := ItemCategory."Parent Category";
        until CurrentCode = '';
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

    local procedure RequireBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
        FormatNextStepLbl: Label 'Send %1 as true or false.', Comment = '%1 = key, is-IS=Sendu %1 sem true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if (Raw <> 'true') and (Raw <> 'false') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
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

    local procedure ReadBoolean(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure UnknownNextStep(): Text
    var
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are code, systemId and includeAttributes.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru code, systemId og includeAttributes.';
    begin
        exit(UnknownNextStepLbl);
    end;

    local procedure NotFoundNextStep(): Text
    var
        NotFoundNextStepLbl: Label 'Check the category code, or read every category by omitting code and systemId.', Comment = 'is-IS=Athugaðu kóða flokksins, eða lestu alla flokka með því að sleppa code og systemId.';
    begin
        exit(NotFoundNextStepLbl);
    end;

    local procedure ConflictNextStep(): Text
    var
        ConflictNextStepLbl: Label 'Send code or systemId, not both.', Comment = 'is-IS=Sendu code eða systemId, ekki bæði.';
    begin
        exit(ConflictNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst með lesheimildum birgða og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
