namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemCategory.Get. Returns the category tree and, when asked, each category's attributes.
/// </summary>
codeunit 70013448 "Item Category Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Reads item categories and their default attributes.', Comment = 'is-IS=Les vöruflokka og sjálfgefna eiginleika þeirra.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item category, parent, attribute, inherited', Comment = 'is-IS=vöruflokkur, foreldri, eiginleiki, erft';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Show the item category tree and the default attributes on each category.', Comment = 'is-IS=Sýndu vöruflokkatréð og sjálfgefna eiginleika hvers flokks.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemCategory.Get');
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
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, 'Category code. Omit it to return every category. Send this or systemId.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Category system id. Send this or code.'));
        Parameters.Add(ContractMgt.Parameter('includeAttributes', 'boolean', false, 'When true, each category includes attribute name, type, value and inherited. Defaults to true.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        EmptyRows: JsonArray;
    begin
        Response.Add('status', 'Success');
        Response.Add('categories', EmptyRows);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required key is empty.', 'Send a non-empty code or systemId, or omit both to read every category.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A key has the wrong JSON type.', 'Send code and systemId as text, and includeAttributes as true or false.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request has an unknown key.', 'Remove the unknown key.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No category matched.', 'Check the category code.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'code and systemId were both sent.', 'Send code or systemId, not both.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The category code is too long, or the Item Category domain is off.', 'Send a code of at most 20 characters, or turn the domain on from Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change item categories.', 'Use the BIFROST InvWrite ori permission set.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
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
        RelatedJson.Add('name', 'Inventory.ItemCategory.Set');
        RelatedJson.Add('useInsteadWhen', 'Create or change a category instead of only reading it.');
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
    begin
        Data.Add('code', 'FURNITURE');
        Data.Add('includeAttributes', true);
        Example.Add('data', Data);
        Examples.Add(Example);
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads item categories with code, description, parent, indentation and presentation order. Set includeAttributes to true to include each attribute name, type, default value and whether it is inherited from a parent category.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'This call does not change categories or attributes.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

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
        TouchDeclaredKeys(RequestJson);
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson, CategoryCode, CategoryId, IncludeAttributes, SelectAll) then
            exit;
        WriteResponse(Argument, CategoryCode, CategoryId, IncludeAttributes, SelectAll);
    end;

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
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', 'BIFROST InvWrite ori', 'Use the BIFROST InvWrite ori permission set.');
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemCategory) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', 'Turn the domain on from the Inventory Setup page.');
            exit(false);
        end;
        exit(true);
    end;

    local procedure TouchDeclaredKeys(RequestJson: JsonObject)
    begin
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('systemId') then;
        if RequestJson.Contains('includeAttributes') then;
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['code', 'systemId', 'includeAttributes']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), '', 'Remove the unknown key. Allowed keys are code, systemId and includeAttributes.');
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var CategoryCode: Code[20]; var CategoryId: Guid; var IncludeAttributes: Boolean; var SelectAll: Boolean): Boolean
    var
        ItemCategory: Record "Item Category";
        CodeText: Text;
        SystemIdText: Text;
        TooLongErr: Label 'code is longer than %1 characters.', Comment = '%1 = maximum length, is-IS=kóði er lengri en %1 stafir.';
    begin
        Clear(CategoryId);
        CategoryCode := '';
        SelectAll := false;
        IncludeAttributes := true;
        if RequestJson.Contains('code') and RequestJson.Contains('systemId') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, 'Send code or systemId, not both.', 'code', '', 'systemId', 'Send code or systemId, not both.');
            exit(false);
        end;
        if RequestJson.Contains('includeAttributes') then begin
            if not RequireBoolean(Argument, RequestJson, 'includeAttributes') then
                exit(false);
            IncludeAttributes := ReadBoolean(RequestJson, 'includeAttributes');
        end;
        if RequestJson.Contains('code') then begin
            if not RequireText(Argument, RequestJson, 'code') then
                exit(false);
            CodeText := ReadText(RequestJson, 'code');
            if CodeText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'code is required when the key is sent.', 'code', '', 'code', 'Send a category code, or omit code to read every category.');
                exit(false);
            end;
            if StrLen(CodeText) > MaxStrLen(ItemCategory.Code) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, MaxStrLen(ItemCategory.Code)), 'code', CopyStr(CodeText, 1, 250), '20', 'Send a category code of at most 20 characters.');
                exit(false);
            end;
            CategoryCode := CopyStr(CodeText, 1, MaxStrLen(ItemCategory.Code));
            exit(true);
        end;
        if RequestJson.Contains('systemId') then begin
            if not RequireText(Argument, RequestJson, 'systemId') then
                exit(false);
            SystemIdText := ReadText(RequestJson, 'systemId');
            if SystemIdText = '' then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, 'systemId is required when the key is sent.', 'systemId', '', 'systemId', 'Send a category system id, or omit it.');
                exit(false);
            end;
            if not Evaluate(CategoryId, SystemIdText) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, 'systemId must be a GUID.', 'systemId', CopyStr(SystemIdText, 1, 250), 'guid', 'Send systemId as a GUID.');
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
            ItemCategory.SetCurrentKey("Presentation Order", Code);
            if ItemCategory.FindSet() then
                repeat
                    Categories.Add(BuildCategoryJson(ItemCategory, IncludeAttributes));
                until ItemCategory.Next() = 0;
        end else begin
            if CategoryCode <> '' then begin
                if not ItemCategory.Get(CategoryCode) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'code', CategoryCode, 'code', 'Check the category code.');
                    exit;
                end;
            end else
                if not ItemCategory.GetBySystemId(CategoryId) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, 'systemId', Format(CategoryId, 0, 4), 'systemId', 'Check the category code.');
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
        Seen: List of [Integer];
        Entry: JsonObject;
        CurrentCode: Code[20];
        OwnCode: Code[20];
    begin
        OwnCode := CategoryCode;
        CurrentCode := CategoryCode;
        ItemCategory.SetLoadFields(Code, "Parent Category");
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        ItemAttribute.SetLoadFields(ID, Name, Type);
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value);
        repeat
            if not ItemCategory.Get(CurrentCode) then
                exit;
            Mapping.SetRange("Table ID", Database::"Item Category");
            Mapping.SetRange("No.", CurrentCode);
            if Mapping.FindSet() then
                repeat
                    if not Seen.Contains(Mapping."Item Attribute ID") then begin
                        Seen.Add(Mapping."Item Attribute ID");
                        if ItemAttribute.Get(Mapping."Item Attribute ID") then
                            if ItemAttributeValue.Get(Mapping."Item Attribute ID", Mapping."Item Attribute Value ID") then begin
                                Clear(Entry);
                                Entry.Add('name', ItemAttribute.Name);
                                Entry.Add('type', Format(ItemAttribute.Type));
                                Entry.Add('value', ItemAttributeValue.Value);
                                Entry.Add('inherited', CurrentCode <> OwnCode);
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

    local procedure RequireBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
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

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() and (not Token.AsValue().IsNull()) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ReadBoolean(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
