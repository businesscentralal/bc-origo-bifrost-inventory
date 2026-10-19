namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCategory.Set. Creates or updates a category and its own attribute defaults.
/// Refusals are answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10036923 "Item Category Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then
            exit(false);
        exit(ItemCategory.WritePermission() and Mapping.WritePermission() and ItemAttribute.ReadPermission() and ItemAttributeValue.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Category");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates or updates an item category and its default attributes.', Comment = 'is-IS=Býr til eða uppfærir vöruflokk og sjálfgefna eiginleika hans.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item category, parent, attribute, default value', Comment = 'is-IS=vöruflokkur, foreldri, eiginleiki, sjálfgefið gildi';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create or change an item category and the default attributes stored on it.', Comment = 'is-IS=Búðu til eða breyttu vöruflokki og sjálfgefnum eiginleikum sem geymdir eru á honum.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemCategory.Set');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item Category');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, 'Category code to create or update. Send this or systemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'System id of an existing category. Send this or code.'));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Description to store on the category.'));
        Parameters.Add(ContractMgt.Parameter('parentCategory', 'string', false, 'Parent category code. Allowed when the category is created. Changing the parent of an existing category is refused.'));
        Parameters.Add(ContractMgt.Parameter('delete', 'boolean', false, 'Deletion is not supported. true is refused.'));
        Parameters.Add(ContractMgt.Parameter('attributes', 'array', false, 'Attribute defaults to store on this category.'));
        Parameters.Add(ContractMgt.Parameter('attributes.name', 'string', false, 'Attribute name. Send this or attributes.id.'));
        Parameters.Add(ContractMgt.Parameter('attributes.id', 'integer', false, 'Attribute id. Send this or attributes.name.'));
        Parameters.Add(ContractMgt.Parameter('attributes.value', 'string', false, 'Existing attribute value. The value is not created by this call.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        EmptyRows: JsonArray;
    begin
        Response.Add('status', 'Success');
        Response.Add('code', '');
        Response.Add('description', '');
        Response.Add('parentCategory', '');
        Response.Add('indentation', 0);
        Response.Add('presentationOrder', 0);
        Response.Add('attributes', EmptyRows);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is missing.', 'Send code or systemId, and name or id plus value on each attribute.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong JSON type.', 'Send text, numbers and true or false as JSON values of that type.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The category, attribute or value does not exist.', 'Create the attribute with Inventory.AttributeDefinition.Create first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Two identifiers were sent for the same record.', 'Send code or systemId, and name or id, not both.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The parent would put the category inside its own subtree.', 'Choose a parent outside this category''s subtree.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The call asks to delete a category or to move an existing category under a new parent.', 'Use the BC page for deletes.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change item categories.', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        RelatedJson: JsonObject;
    begin
        RelatedJson.Add('name', 'Inventory.ItemCategory.Get');
        RelatedJson.Add('useInsteadWhen', 'Read the category tree instead of changing it.');
        Related.Add(RelatedJson);
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Example: JsonObject;
        Data: JsonObject;
        Attributes: JsonArray;
        Attribute: JsonObject;
    begin
        Attribute.Add('name', 'Color');
        Attribute.Add('value', 'Blue');
        Attributes.Add(Attribute);
        Data.Add('code', 'CHAIRS');
        Data.Add('description', 'Chairs');
        Data.Add('parentCategory', 'FURNITURE');
        Data.Add('attributes', Attributes);
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates an item category or updates its description and the attribute defaults stored on that category. A value equal to the inherited parent value stays inherited. Deleting a category and moving an existing category to another parent are refused.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'A successful call saves the category. A refusal leaves every category and attribute unchanged. This call does not post documents and does not delete categories.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if not Codeunit.Run(Codeunit::"Item Category Set Proc ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        DomainDisabledErr: Label 'The Item Category domain is turned off for this company.', Comment = 'is-IS=Vöruflokkssviðið er slökkt fyrir þetta fyrirtæki.';
    begin
        if (not InventorySetup.ReadPermission()) or (not ItemCategory.WritePermission()) or (not Mapping.WritePermission()) or (not ItemAttribute.ReadPermission()) or (not ItemAttributeValue.ReadPermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', 'BIFROST InvWrite ori', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change these tables.');
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', 'Turn the domain on from the Inventory Setup page.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    var
        Attributes: JsonArray;
        AttributeToken: JsonToken;
        AttributeJson: JsonObject;
        Index: Integer;
    begin
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('description') then;
        if RequestJson.Contains('parentCategory') then;
        if RequestJson.Contains('delete') then;
        if RequestJson.Contains('attributes') then;
        if not ReadArray(RequestJson, 'attributes', Attributes) then
            exit;
        for Index := 0 to Attributes.Count() - 1 do begin
            Attributes.Get(Index, AttributeToken);
            if AttributeToken.IsObject() then begin
                AttributeJson := AttributeToken.AsObject();
                if AttributeJson.Contains('name') then;
                if AttributeJson.Contains('id') then;
                if AttributeJson.Contains('value') then;
            end;
        end;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['code', 'systemId', 'description', 'parentCategory', 'delete', 'attributes']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key. Allowed keys are code, systemId, description, parentCategory, delete and attributes.');
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
        DeleteRequested: Boolean;
    begin
        if not ValidateShapes(Argument, RequestJson) then
            exit(false);
        if RequestJson.Contains('delete') then
            DeleteRequested := ReadBoolean(RequestJson, 'delete');
        if DeleteRequested then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'Deleting a category is not part of this call.', 'delete', 'true', 'false', 'Use the BC page for deletes.');
            exit(false);
        end;
        if RequestJson.Contains('code') and RequestJson.Contains('systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send code or systemId, not both.', 'code', '', 'systemId', 'Send code or systemId, not both.');
            exit(false);
        end;
        if (not RequestJson.Contains('code')) and (not RequestJson.Contains('systemId')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'code or systemId is required.', 'code', '', 'code', 'Send code or systemId.');
            exit(false);
        end;
        if not ReadCategoryIdentity(Argument, RequestJson, ItemCategory, CategoryCode, CategoryExists) then
            exit(false);
        if CategoryExists then
            CurrentParent := ItemCategory."Parent Category";
        if not ValidateParent(Argument, RequestJson, CategoryCode, CategoryExists, CurrentParent) then
            exit(false);
        if not ValidateAttributes(Argument, RequestJson) then
            exit(false);
        exit(true);
    end;

    local procedure ValidateShapes(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        ItemCategory: Record "Item Category";
        CodeText: Text;
        DescriptionText: Text;
        ParentText: Text;
        TooLongErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key, %2 = maximum, is-IS=%1 er lengra en %2 stafir.';
    begin
        if RequestJson.Contains('code') then begin
            if not RequireText(Argument, RequestJson, 'code') then
                exit(false);
            CodeText := ReadText(RequestJson, 'code');
            if CodeText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'code is required when the key is sent.', 'code', '', 'code', 'Send a category code.');
                exit(false);
            end;
            if StrLen(CodeText) > MaxStrLen(ItemCategory.Code) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, 'code', MaxStrLen(ItemCategory.Code)), 'code', CopyStr(CodeText, 1, 250), '20', 'Send a category code of at most 20 characters.');
                exit(false);
            end;
        end;
        if RequestJson.Contains('systemId') then
            if not RequireGuid(Argument, RequestJson, 'systemId') then
                exit(false);
        if RequestJson.Contains('description') then begin
            if not RequireText(Argument, RequestJson, 'description') then
                exit(false);
            DescriptionText := ReadText(RequestJson, 'description');
            if StrLen(DescriptionText) > MaxStrLen(ItemCategory.Description) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, 'description', MaxStrLen(ItemCategory.Description)), 'description', CopyStr(DescriptionText, 1, 250), '100', 'Send a description of at most 100 characters.');
                exit(false);
            end;
        end;
        if RequestJson.Contains('parentCategory') then begin
            if not RequireText(Argument, RequestJson, 'parentCategory') then
                exit(false);
            ParentText := ReadText(RequestJson, 'parentCategory');
            if StrLen(ParentText) > MaxStrLen(ItemCategory."Parent Category") then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, 'parentCategory', MaxStrLen(ItemCategory."Parent Category")), 'parentCategory', CopyStr(ParentText, 1, 250), '20', 'Send a parent category code of at most 20 characters.');
                exit(false);
            end;
        end;
        if RequestJson.Contains('delete') then
            if not RequireBoolean(Argument, RequestJson, 'delete') then
                exit(false);
        if RequestJson.Contains('attributes') then
            if not RequireArray(Argument, RequestJson, 'attributes') then
                exit(false);
        exit(true);
    end;

    local procedure ReadCategoryIdentity(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemCategory: Record "Item Category"; var CategoryCode: Code[20]; var CategoryExists: Boolean): Boolean
    var
        CategoryId: Guid;
        NotFoundErr: Label 'No item category matched.', Comment = 'is-IS=Enginn vöruflokkur fannst.';
    begin
        CategoryExists := false;
        CategoryCode := '';
        ItemCategory.SetLoadFields(Code, "Parent Category", Description);
        if RequestJson.Contains('systemId') then begin
            Evaluate(CategoryId, ReadText(RequestJson, 'systemId'));
            if not ItemCategory.GetBySystemId(CategoryId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'systemId', Format(CategoryId, 0, 4), 'systemId', 'Check the category code.');
                exit(false);
            end;
            CategoryCode := ItemCategory.Code;
            CategoryExists := true;
            exit(true);
        end;
        CategoryCode := CopyStr(ReadText(RequestJson, 'code'), 1, MaxStrLen(ItemCategory.Code));
        CategoryExists := ItemCategory.Get(CategoryCode);
        exit(true);
    end;

    local procedure ValidateParent(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; CategoryCode: Code[20]; CategoryExists: Boolean; CurrentParent: Code[20]): Boolean
    var
        ParentCategory: Record "Item Category";
        ParentCode: Code[20];
        ParentMissingErr: Label 'The parent category does not exist.', Comment = 'is-IS=Foreldrisflokkurinn er ekki til.';
        LoopErr: Label 'The parent would put this category inside its own subtree.', Comment = 'is-IS=Foreldrið myndi setja þennan flokk inn í sitt eigið undirtré.';
        ReparentErr: Label 'Changing the parent of an existing category is not part of this call.', Comment = 'is-IS=Það er ekki hluti af þessu kalli að breyta foreldri flokks sem er til.';
    begin
        ParentCode := '';
        if not RequestJson.Contains('parentCategory') then
            exit(true);
        ParentCode := CopyStr(ReadText(RequestJson, 'parentCategory'), 1, MaxStrLen(ParentCategory.Code));
        if ParentCode <> '' then begin
            ParentCategory.SetLoadFields(Code);
            if not ParentCategory.Get(ParentCode) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, ParentMissingErr, 'parentCategory', ParentCode, 'parentCategory', 'Check the parent category code.');
                exit(false);
            end;
        end;
        if WouldLoop(CategoryCode, ParentCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, LoopErr, 'parentCategory', ParentCode, 'parent', 'Choose a parent outside this category''s subtree.');
            exit(false);
        end;
        if CategoryExists and (ParentCode <> CurrentParent) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, ReparentErr, 'parentCategory', ParentCode, CurrentParent, 'Use the BC page for deletes.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure WouldLoop(CategoryCode: Code[20]; ParentCode: Code[20]): Boolean
    var
        ItemCategory: Record "Item Category";
        Walk: Code[20];
        Steps: Integer;
    begin
        if ParentCode = '' then
            exit(false);
        if ParentCode = CategoryCode then
            exit(true);
        Walk := ParentCode;
        Steps := 0;
        ItemCategory.SetLoadFields(Code, "Parent Category");
        while ItemCategory.Get(Walk) and (Steps < 100) do begin
            Steps += 1;
            if ItemCategory.Code = CategoryCode then
                exit(true);
            if ItemCategory."Parent Category" = '' then
                exit(false);
            if ItemCategory."Parent Category" = Walk then
                exit(true);
            Walk := ItemCategory."Parent Category";
        end;
        exit(Steps >= 100);
    end;

    local procedure ValidateAttributes(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Attributes: JsonArray;
        AttributeToken: JsonToken;
        AttributeJson: JsonObject;
        Index: Integer;
        NotObjectErr: Label 'Each attributes entry must be an object.', Comment = 'is-IS=Hver eiginleikafærsla verður að vera hlutur.';
    begin
        if not RequestJson.Contains('attributes') then
            exit(true);
        if not ReadArray(RequestJson, 'attributes', Attributes) then
            exit(false);
        for Index := 0 to Attributes.Count() - 1 do begin
            Attributes.Get(Index, AttributeToken);
            if not AttributeToken.IsObject() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, NotObjectErr, 'attributes', Format(Index), 'object', 'Send each attributes entry as an object.');
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
        UnknownKeyErr: Label 'The attribute entry contains an unknown key.', Comment = 'is-IS=Eiginleikafærslan inniheldur óþekktan lykil.';
    begin
        foreach KeyName in AttributeJson.Keys() do
            if not (KeyName in ['name', 'id', 'value']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key. Allowed keys are name, id and value.');
                exit(false);
            end;
        if AttributeJson.Contains('name') and AttributeJson.Contains('id') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send name or id, not both.', 'name', '', 'id', 'Send name or id, not both.');
            exit(false);
        end;
        if (not AttributeJson.Contains('name')) and (not AttributeJson.Contains('id')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'Attribute name or id is required.', 'name', '', 'name', 'Send the attribute name or id.');
            exit(false);
        end;
        if not AttributeJson.Contains('value') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'Attribute value is required.', 'value', '', 'value', 'Send the attribute value.');
            exit(false);
        end;
        if not RequireText(Argument, AttributeJson, 'value') then
            exit(false);
        if not FindAttribute(Argument, AttributeJson, ItemAttribute) then
            exit(false);
        if ItemAttribute.Blocked then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The attribute is blocked.', 'name', ItemAttribute.Name, 'not blocked', 'Choose an attribute that is not blocked.');
            exit(false);
        end;
        if not FindValue(Argument, ItemAttribute, ReadText(AttributeJson, 'value'), ItemAttributeValue) then
            exit(false);
        if ItemAttributeValue.Blocked then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, 'The attribute value is blocked.', 'value', ItemAttributeValue.Value, 'not blocked', 'Choose an attribute value that is not blocked.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure FindAttribute(var Argument: Record "Message Argument ori"; AttributeJson: JsonObject; var ItemAttribute: Record "Item Attribute"): Boolean
    var
        AttributeId: Integer;
        AttributeName: Text;
        MissingErr: Label 'The attribute does not exist.', Comment = 'is-IS=Eiginleikinn er ekki til.';
        CreateNextStepTxt: Label 'Create the attribute with Inventory.AttributeDefinition.Create first.', Comment = 'is-IS=Búðu fyrst til eiginleikann með Inventory.AttributeDefinition.Create.';
    begin
        ItemAttribute.SetLoadFields(ID, Name, Type, Blocked);
        if AttributeJson.Contains('id') then begin
            if not RequireInteger(Argument, AttributeJson, 'id') then
                exit(false);
            AttributeId := ReadInteger(AttributeJson, 'id');
            if not ItemAttribute.Get(AttributeId) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'id', Format(AttributeId), 'id', CreateNextStepTxt);
                exit(false);
            end;
            exit(true);
        end;
        if not RequireText(Argument, AttributeJson, 'name') then
            exit(false);
        AttributeName := ReadText(AttributeJson, 'name');
        if AttributeName = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'Attribute name is required when the key is sent.', 'name', '', 'name', 'Send the attribute name or id.');
            exit(false);
        end;
        ItemAttribute.SetRange(Name, CopyStr(AttributeName, 1, MaxStrLen(ItemAttribute.Name)));
        if not ItemAttribute.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'name', CopyStr(AttributeName, 1, 250), 'name', CreateNextStepTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure FindValue(var Argument: Record "Message Argument ori"; ItemAttribute: Record "Item Attribute"; ValueText: Text; var ItemAttributeValue: Record "Item Attribute Value"): Boolean
    var
        NumericValue: Decimal;
        DateValue: Date;
        MissingErr: Label 'The attribute value does not exist.', Comment = 'is-IS=Gildi eiginleikans er ekki til.';
        CreateNextStepTxt: Label 'Create the attribute with Inventory.AttributeDefinition.Create first.', Comment = 'is-IS=Búðu fyrst til eiginleikann með Inventory.AttributeDefinition.Create.';
    begin
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value", Blocked);
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        case ItemAttribute.Type of
            ItemAttribute.Type::Integer, ItemAttribute.Type::Decimal:
                if not Evaluate(NumericValue, ValueText) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'value', CopyStr(ValueText, 1, 250), 'value', CreateNextStepTxt);
                    exit(false);
                end else
                    ItemAttributeValue.SetRange("Numeric Value", NumericValue);
            ItemAttribute.Type::Date:
                if not Evaluate(DateValue, ValueText) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'value', CopyStr(ValueText, 1, 250), 'value', CreateNextStepTxt);
                    exit(false);
                end else
                    ItemAttributeValue.SetRange("Date Value", DateValue);
            else
                ItemAttributeValue.SetRange(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
        end;
        if not ItemAttributeValue.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingErr, 'value', CopyStr(ValueText, 1, 250), 'value', CreateNextStepTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, KeyName + ' is required.', CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), 'Send ' + KeyName + '.');
            exit(false);
        end;
        if (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', 'text', 'Send ' + KeyName + ' as text.');
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), 'text', 'Send ' + KeyName + ' as text.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Probe: Decimal;
        FormatErr: Label '%1 must be a number.', Comment = '%1 = key, is-IS=%1 verður að vera tala.';
    begin
        if not RequestJson.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, KeyName + ' is required.', CopyStr(KeyName, 1, 250), '', CopyStr(KeyName, 1, 250), 'Send ' + KeyName + '.');
            exit(false);
        end;
        if (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', 'number', 'Send ' + KeyName + ' as a number.');
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (not Evaluate(Probe, Raw)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), 'number', 'Send ' + KeyName + ' as a number.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if (not Token.IsValue()) or Token.AsValue().IsNull() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', 'boolean', 'Send ' + KeyName + ' as true or false.');
            exit(false);
        end;
        Token.WriteTo(Raw);
        if (Raw <> 'true') and (Raw <> 'false') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), 'boolean', 'Send ' + KeyName + ' as true or false.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireArray(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        FormatErr: Label '%1 must be an array.', Comment = '%1 = key, is-IS=%1 verður að vera fylki.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if not Token.IsArray() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', 'array', 'Send ' + KeyName + ' as an array.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure RequireGuid(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        CategoryId: Guid;
        SystemIdText: Text;
    begin
        if not RequireText(Argument, RequestJson, KeyName) then
            exit(false);
        SystemIdText := ReadText(RequestJson, KeyName);
        if SystemIdText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'systemId is required when the key is sent.', 'systemId', '', 'systemId', 'Send a category system id.');
            exit(false);
        end;
        if not Evaluate(CategoryId, SystemIdText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'systemId must be a GUID.', 'systemId', CopyStr(SystemIdText, 1, 250), 'guid', 'Send systemId as a GUID.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and (not Token.AsValue().IsNull()) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadInteger(RequestJson: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure ReadBoolean(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;

    local procedure ReadArray(RequestJson: JsonObject; KeyName: Text; var Result: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsArray() then begin
            Result := Token.AsArray();
            exit(true);
        end;
        exit(false);
    end;
}
