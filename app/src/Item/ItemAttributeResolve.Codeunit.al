namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Shared helpers for Item Attribute message types: type-name mapping, name→id resolution,
/// value coercion, and JSON attribute object building. Reuses base-app
/// <c>Item Attribute Management</c> for mapping inserts where applicable.
/// </summary>
codeunit 10076844 "Item Attribute Resolve ori"
{
    Access = Internal;

    var
        AttributeNotFoundErr: Label 'Item attribute "%1" was not found.', Comment = '%1 = Attribute name or id||is-IS=Vörueigindin "%1" fannst ekki.';
        AttributeTypeMismatchErr: Label 'Attribute "%1" has type %2; request type %3 does not match.', Comment = '%1 = Name, %2 = Actual type, %3 = Requested type||is-IS=Eigindin "%1" er af gerðinni %2; gerðin %3 í beiðninni passar ekki.';
        OptionValueMissingErr: Label 'Option value "%1" was not found for attribute "%2". Pass createValueIfMissing: true to create it.', Comment = '%1 = Value, %2 = Attribute name||is-IS=Valkostsgildið "%1" fannst ekki fyrir eigindina "%2". Sendu createValueIfMissing: true til að stofna það.';
        MappingConflictErr: Label 'Item "%1" already has attribute "%2" with a different value. Pass overwrite: true or use Inventory.Attribute.Update.', Comment = '%1 = Item No., %2 = Attribute name||is-IS=Varan "%1" hefur þegar eigindina "%2" með öðru gildi. Sendu overwrite: true eða notaðu Inventory.Attribute.Update.';
        MappingMissingErr: Label 'Item "%1" has no mapping for attribute "%2". Use Inventory.Attribute.Create first.', Comment = '%1 = Item No., %2 = Attribute name||is-IS=Varan "%1" hefur enga tengingu við eigindina "%2". Notaðu Inventory.Attribute.Create fyrst.';
        ItemBlockedErr: Label 'Item "%1" is blocked. Pass allowBlocked: true to override.', Comment = '%1 = Item No.||is-IS=Varan "%1" er lokuð. Sendu allowBlocked: true til að leyfa breytinguna.';
        AttributesRequiredErr: Label 'Request data.attributes must be a non-empty array.', Comment = 'is-IS=data.attributes í beiðninni verður að vera fylki sem er ekki tómt.';
        NameRequiredErr: Label 'Attribute definition requires data.name.', Comment = 'is-IS=Skilgreining eigindar krefst data.name.';
        TypeRequiredErr: Label 'Attribute definition requires data.type.', Comment = 'is-IS=Skilgreining eigindar krefst data.type.';
        DuplicateAttributeErr: Label 'Item attribute "%1" already exists.', Comment = '%1 = Attribute name||is-IS=Vörueigindin "%1" er þegar til.';
        UnknownTypeErr: Label 'Unknown attribute type "%1". Expected Option, Text, Integer, Decimal, or Date.', Comment = '%1 = Type name||is-IS=Óþekkt gerð eigindar "%1". Búist var við Option, Text, Integer, Decimal eða Date.';
        ValueRequiredErr: Label 'A value is required for attribute "%1".', Comment = '%1 = Attribute name||is-IS=Gildi er nauðsynlegt fyrir eigindina "%1".';

    /// <summary>Validates every mapping request without creating values or changing mappings.</summary>
    procedure ValidateMappings(var Argument: Record "Message Argument ori"; Updating: Boolean): Boolean
    var
        Item: Record Item;
        Request: JsonObject;
        Attributes: JsonArray;
        Token: JsonToken;
        Entry: JsonToken;
        Index: Integer;
        ArrayExpectedLbl: Label 'a non-empty array of attribute objects', Comment = 'is-IS=fylki eigindahluta sem er ekki tómt';
        ArrayNextLbl: Label 'Send at least one attribute object in data.attributes.', Comment = 'is-IS=Sendu a.m.k. einn eigindahlut í data.attributes.';
        ObjectErr: Label 'Each attribute entry must be an object.', Comment = 'is-IS=Hver eigindafærsla verður að vera hlutur.';
        ObjectExpectedLbl: Label 'an attribute object', Comment = 'is-IS=eigindahlutur';
        ObjectNextLbl: Label 'Send name or attributeId and a value in each attribute object.', Comment = 'is-IS=Sendu name eða attributeId og gildi í hverjum eigindahlut.';
        BlockedExpectedLbl: Label 'an unblocked item or allowBlocked true', Comment = 'is-IS=ólokuð vara eða allowBlocked true';
        BlockedNextLbl: Label 'Unblock the item or send allowBlocked true for an intentional write.', Comment = 'is-IS=Opnaðu vöruna eða sendu allowBlocked true fyrir fyrirhugaða breytingu.';
    begin
        Request := Argument.GetRequestJson();
        if not Request.Get('attributes', Token) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, AttributesRequiredErr, 'attributes', '', ArrayExpectedLbl, ArrayNextLbl));
        if not Token.IsArray() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, AttributesRequiredErr, 'attributes', '', ArrayExpectedLbl, ArrayNextLbl));
        Attributes := Token.AsArray();
        if Attributes.Count() = 0 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, AttributesRequiredErr, 'attributes', '', ArrayExpectedLbl, ArrayNextLbl));
        if not ResolveSingleItem(Argument, Item) then
            exit(false);
        if Item.Blocked and not GetBool(Request, 'allowBlocked', false) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ItemBlockedErr, Item."No."), 'allowBlocked', 'false', BlockedExpectedLbl, BlockedNextLbl));
        foreach Entry in Attributes do begin
            Index += 1;
            if not Entry.IsObject() then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidLine, ObjectErr, AttributePath(Index, ''), '', ObjectExpectedLbl, ObjectNextLbl));
            if not ValidateMapping(Argument, Item, Entry.AsObject(), Index, Updating) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateMapping(var Argument: Record "Message Argument ori"; Item: Record Item; Request: JsonObject; Index: Integer; Updating: Boolean): Boolean
    var
        Attribute: Record "Item Attribute";
        NamedAttribute: Record "Item Attribute";
        RequestedType: Record "Item Attribute";
        Value: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        AttributeId: Integer;
        AttributeName: Text;
        RequestedTypeText: Text;
        ValueText: Text;
        IdentityErr: Label 'An attribute name or attributeId is required.', Comment = 'is-IS=Heiti eigindar eða attributeId er nauðsynlegt.';
        IdentityExpectedLbl: Label 'an existing attribute name or attributeId', Comment = 'is-IS=heiti fyrirliggjandi eigindar eða attributeId';
        IdentityNextLbl: Label 'Send an existing attribute or create it with Inventory.AttributeDefinition.Create.', Comment = 'is-IS=Sendu fyrirliggjandi eigind eða stofnaðu hana með Inventory.AttributeDefinition.Create.';
        ConflictErr: Label 'attributeId and name identify different attributes.', Comment = 'is-IS=attributeId og name auðkenna ólíkar eigindir.';
        ConflictNextLbl: Label 'Send one identifier or identifiers for the same attribute.', Comment = 'is-IS=Sendu eitt auðkenni eða auðkenni sömu eigindar.';
        ValueExpectedLbl: Label 'a value matching the attribute type', Comment = 'is-IS=gildi sem passar við gerð eigindar';
        ValueNextLbl: Label 'Send value, numericValue or dateValue matching the attribute type.', Comment = 'is-IS=Sendu value, numericValue eða dateValue sem passar við gerð eigindar.';
        OptionNextLbl: Label 'Send an existing option value or set createValueIfMissing true on this attribute.', Comment = 'is-IS=Sendu fyrirliggjandi valkostsgildi eða stilltu createValueIfMissing true á þessari eigind.';
        MappingExpectedLbl: Label 'an existing item attribute mapping', Comment = 'is-IS=fyrirliggjandi tenging vörueigindar';
        MappingNextLbl: Label 'Create the mapping with Inventory.Attribute.Create first.', Comment = 'is-IS=Stofnaðu tenginguna fyrst með Inventory.Attribute.Create.';
        OverwriteExpectedLbl: Label 'the existing value or overwrite true', Comment = 'is-IS=fyrirliggjandi gildi eða overwrite true';
        OverwriteNextLbl: Label 'Set overwrite true on this attribute or use Inventory.Attribute.Update.', Comment = 'is-IS=Stilltu overwrite true á þessari eigind eða notaðu Inventory.Attribute.Update.';
    begin
        AttributeId := GetInteger(Request, 'attributeId');
        AttributeName := GetText(Request, 'name');
        if AttributeName = '' then
            AttributeName := GetText(Request, 'attributeName');
        if (AttributeId = 0) and (AttributeName = '') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, IdentityErr, AttributePath(Index, 'name'), '', IdentityExpectedLbl, IdentityNextLbl));
        if not FindAttribute(AttributeId, AttributeName, Attribute) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(AttributeNotFoundErr, AttributeName), AttributePath(Index, 'name'), AttributeName, IdentityExpectedLbl, IdentityNextLbl));
        if (AttributeId <> 0) and (AttributeName <> '') then
            if FindAttribute(0, AttributeName, NamedAttribute) then
                if Attribute.ID <> NamedAttribute.ID then
                    exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, AttributePath(Index, 'attributeId'), Format(AttributeId, 0, 9), IdentityExpectedLbl, ConflictNextLbl));
        RequestedTypeText := GetText(Request, 'type');
        if RequestedTypeText <> '' then begin
            if not TryParseType(RequestedTypeText, RequestedType) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTypeErr, RequestedTypeText), AttributePath(Index, 'type'), RequestedTypeText, ValueExpectedLbl, ValueNextLbl));
            if RequestedType.Type <> Attribute.Type then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, StrSubstNo(AttributeTypeMismatchErr, Attribute.Name, TypeName(Attribute), RequestedTypeText), AttributePath(Index, 'type'), RequestedTypeText, ValueExpectedLbl, ValueNextLbl));
        end;
        if not Request.Contains('value') and not Request.Contains('numericValue') and not Request.Contains('dateValue') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(ValueRequiredErr, Attribute.Name), AttributePath(Index, 'value'), '', ValueExpectedLbl, ValueNextLbl));
        if not FindRequestedValue(Attribute, Request, Value) then begin
            ClearLastError();
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ValueRequiredErr, Attribute.Name), AttributePath(Index, 'value'), '', ValueExpectedLbl, ValueNextLbl));
        end;
        if (Attribute.Type = Attribute.Type::Option) and (Value.ID = 0) and not GetBool(Request, 'createValueIfMissing', false) then begin
            ValueText := GetText(Request, 'value');
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(OptionValueMissingErr, ValueText, Attribute.Name), AttributePath(Index, 'value'), ValueText, ValueExpectedLbl, OptionNextLbl));
        end;
        if Mapping.Get(Database::Item, Item."No.", Attribute.ID) then begin
            if not Updating and (Mapping."Item Attribute Value ID" <> Value.ID) and not GetBool(Request, 'overwrite', false) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(MappingConflictErr, Item."No.", Attribute.Name), AttributePath(Index, 'overwrite'), 'false', OverwriteExpectedLbl, OverwriteNextLbl));
        end else
            if Updating then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(MappingMissingErr, Item."No.", Attribute.Name), AttributePath(Index, 'name'), Attribute.Name, MappingExpectedLbl, MappingNextLbl));
        exit(true);
    end;

    // Read-only TryFunction: conversion failures become a coded refusal before any write process runs.
    [TryFunction]
    local procedure FindRequestedValue(Attribute: Record "Item Attribute"; Request: JsonObject; var Value: Record "Item Attribute Value")
    var
        TextValue: Text;
        NumericValue: Decimal;
        DateValue: Date;
    begin
        Clear(Value);
        Value.SetRange("Attribute ID", Attribute.ID);
        TextValue := GetText(Request, 'value');
        case Attribute.Type of
            Attribute.Type::Option, Attribute.Type::Text:
                begin
                    if TextValue = '' then
                        Error(ValueRequiredErr, Attribute.Name);
                    Value.SetRange(Value, CopyStr(TextValue, 1, MaxStrLen(Value.Value)));
                end;
            Attribute.Type::Integer, Attribute.Type::Decimal:
                begin
                    if not GetDecimal(Request, 'numericValue', NumericValue) then
                        if not Evaluate(NumericValue, TextValue, 9) then
                            Error(ValueRequiredErr, Attribute.Name);
                    if (Attribute.Type = Attribute.Type::Integer) and (NumericValue <> Round(NumericValue, 1)) then
                        Error(ValueRequiredErr, Attribute.Name);
                    Value.SetRange("Numeric Value", NumericValue);
                end;
            Attribute.Type::Date:
                begin
                    if not GetDate(Request, 'dateValue', DateValue) then
                        if not Evaluate(DateValue, TextValue, 9) then
                            Error(ValueRequiredErr, Attribute.Name);
                    Value.SetRange("Date Value", DateValue);
                end;
        end;
        if Value.FindFirst() then;
    end;

    /// <summary>Checks definition identity and type before the write process starts.</summary>
    procedure ValidateDefinition(var Argument: Record "Message Argument ori"): Boolean
    var
        Attribute: Record "Item Attribute";
        Request: JsonObject;
        NameText: Text;
        TypeText: Text;
        NameExpectedLbl: Label 'a new non-empty attribute name', Comment = 'is-IS=nýtt heiti eigindar sem er ekki tómt';
        NameNextLbl: Label 'Send a new name or use the existing attribute definition.', Comment = 'is-IS=Sendu nýtt heiti eða notaðu fyrirliggjandi skilgreiningu eigindar.';
        TypeExpectedLbl: Label 'Option, Text, Integer, Decimal or Date', Comment = 'is-IS=Option, Text, Integer, Decimal eða Date';
        TypeNextLbl: Label 'Send Option, Text, Integer, Decimal or Date in data.type.', Comment = 'is-IS=Sendu Option, Text, Integer, Decimal eða Date í data.type.';
    begin
        Request := Argument.GetRequestJson();
        NameText := GetText(Request, 'name');
        TypeText := GetText(Request, 'type');
        if NameText = '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, NameRequiredErr, 'name', '', NameExpectedLbl, NameNextLbl));
        if TypeText = '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, TypeRequiredErr, 'type', '', TypeExpectedLbl, TypeNextLbl));
        if not TryParseType(TypeText, Attribute) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnknownTypeErr, TypeText), 'type', TypeText, TypeExpectedLbl, TypeNextLbl));
        Attribute.SetRange(Name, CopyStr(NameText, 1, MaxStrLen(Attribute.Name)));
        if not Attribute.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DuplicateAttributeErr, NameText), 'name', NameText, NameExpectedLbl, NameNextLbl));
        exit(true);
    end;

    local procedure AttributePath(Index: Integer; KeyName: Text): Text
    begin
        if KeyName = '' then
            exit('attributes[' + Format(Index, 0, 9) + ']');
        exit('attributes[' + Format(Index, 0, 9) + '].' + KeyName);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ErrorText: Text; ParameterName: Text; Received: Text; Expected: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, ErrorText, ParameterName, Received, Expected, NextStep);
        exit(false);
    end;

    /// <summary>Returns the Option member name for an Item Attribute Type (never Format of ordinal).</summary>
    /// <param name="ItemAttribute">The attribute whose Type to emit.</param>
    /// <returns>Option, Text, Integer, Decimal, or Date.</returns>
    procedure TypeName(ItemAttribute: Record "Item Attribute"): Text
    begin
        case ItemAttribute.Type of
            ItemAttribute.Type::Option:
                exit('Option');
            ItemAttribute.Type::Text:
                exit('Text');
            ItemAttribute.Type::Integer:
                exit('Integer');
            ItemAttribute.Type::Decimal:
                exit('Decimal');
            ItemAttribute.Type::Date:
                exit('Date');
        end;
        exit('');
    end;

    /// <summary>Parses a type name string into the Item Attribute Type option.</summary>
    /// <param name="TypeText">Option/Text/Integer/Decimal/Date.</param>
    /// <param name="ItemAttribute">Record whose Type field is set on success.</param>
    /// <returns>True when recognised.</returns>
    procedure TryParseType(TypeText: Text; var ItemAttribute: Record "Item Attribute"): Boolean
    begin
        case UpperCase(TypeText) of
            'OPTION':
                ItemAttribute.Type := ItemAttribute.Type::Option;
            'TEXT':
                ItemAttribute.Type := ItemAttribute.Type::Text;
            'INTEGER':
                ItemAttribute.Type := ItemAttribute.Type::Integer;
            'DECIMAL':
                ItemAttribute.Type := ItemAttribute.Type::Decimal;
            'DATE':
                ItemAttribute.Type := ItemAttribute.Type::Date;
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>Finds an Item Attribute by id or name.</summary>
    /// <param name="AttributeId">Optional numeric id (0 = ignore).</param>
    /// <param name="AttributeName">Optional name.</param>
    /// <param name="ItemAttribute">Out: found attribute.</param>
    /// <returns>True when found.</returns>
    procedure FindAttribute(AttributeId: Integer; AttributeName: Text; var ItemAttribute: Record "Item Attribute"): Boolean
    begin
        ItemAttribute.SetLoadFields(ID, Name, Type, "Unit of Measure", Blocked);
        if AttributeId <> 0 then
            if ItemAttribute.Get(AttributeId) then
                exit(true);
        if AttributeName <> '' then begin
            ItemAttribute.Reset();
            ItemAttribute.SetLoadFields(ID, Name, Type, "Unit of Measure", Blocked);
            ItemAttribute.SetRange(Name, CopyStr(AttributeName, 1, MaxStrLen(ItemAttribute.Name)));
            exit(ItemAttribute.FindFirst());
        end;
        exit(false);
    end;

    /// <summary>Builds one attribute JSON object for Get responses.</summary>
    procedure BuildAttributeJson(ItemAttribute: Record "Item Attribute"; ItemAttributeValue: Record "Item Attribute Value"; HasValue: Boolean) AttributeJson: JsonObject
    begin
        AttributeJson.Add('attributeId', ItemAttribute.ID);
        AttributeJson.Add('attributeName', ItemAttribute.Name);
        AttributeJson.Add('type', TypeName(ItemAttribute));
        AttributeJson.Add('unitOfMeasure', ItemAttribute."Unit of Measure");
        if HasValue then begin
            AttributeJson.Add('valueId', ItemAttributeValue.ID);
            AttributeJson.Add('value', ItemAttributeValue.Value);
            if ItemAttribute.Type in [ItemAttribute.Type::Integer, ItemAttribute.Type::Decimal] then
                AttributeJson.Add('numericValue', ItemAttributeValue."Numeric Value")
            else
                AttributeJson.Add('numericValue', '');
            if ItemAttribute.Type = ItemAttribute.Type::Date then
                AttributeJson.Add('dateValue', Format(ItemAttributeValue."Date Value", 0, 9))
            else
                AttributeJson.Add('dateValue', '');
        end else begin
            AttributeJson.Add('valueId', 0);
            AttributeJson.Add('value', '');
            AttributeJson.Add('numericValue', '');
            AttributeJson.Add('dateValue', '');
        end;
    end;

    /// <summary>Collects attribute JSON for one item into an array.</summary>
    procedure CollectItemAttributes(Item: Record Item; AttributeNameFilter: List of [Text]; AttributeIdFilter: List of [Integer]; IncludeUnassigned: Boolean; var AttributesArray: JsonArray)
    var
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        AttrJson: JsonObject;
        FilterByName: Boolean;
        FilterById: Boolean;
        IncludeThis: Boolean;
    begin
        FilterByName := AttributeNameFilter.Count() > 0;
        FilterById := AttributeIdFilter.Count() > 0;

        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        Mapping.SetRange("Table ID", Database::Item);
        Mapping.SetRange("No.", Item."No.");
        if Mapping.FindSet() then
            repeat
                if ItemAttribute.Get(Mapping."Item Attribute ID") then begin
                    IncludeThis := true;
                    if FilterById then
                        IncludeThis := AttributeIdFilter.Contains(ItemAttribute.ID);
                    if FilterByName then
                        IncludeThis := AttributeNameFilter.Contains(ItemAttribute.Name);
                    if IncludeThis then begin
                        Clear(ItemAttributeValue);
                        if ItemAttributeValue.Get(Mapping."Item Attribute ID", Mapping."Item Attribute Value ID") then;
                        AttrJson := BuildAttributeJson(ItemAttribute, ItemAttributeValue, ItemAttributeValue.ID <> 0);
                        AttributesArray.Add(AttrJson);
                    end;
                end;
            until Mapping.Next() = 0;

        if IncludeUnassigned then begin
            ItemAttribute.Reset();
            ItemAttribute.SetLoadFields(ID, Name, Type, "Unit of Measure", Blocked);
            if ItemAttribute.FindSet() then
                repeat
                    IncludeThis := true;
                    if FilterById then
                        IncludeThis := AttributeIdFilter.Contains(ItemAttribute.ID);
                    if FilterByName then
                        IncludeThis := AttributeNameFilter.Contains(ItemAttribute.Name);
                    if IncludeThis then begin
                        Mapping.Reset();
                        Mapping.SetRange("Table ID", Database::Item);
                        Mapping.SetRange("No.", Item."No.");
                        Mapping.SetRange("Item Attribute ID", ItemAttribute.ID);
                        if Mapping.IsEmpty() then begin
                            Clear(ItemAttributeValue);
                            AttrJson := BuildAttributeJson(ItemAttribute, ItemAttributeValue, false);
                            AttributesArray.Add(AttrJson);
                        end;
                    end;
                until ItemAttribute.Next() = 0;
        end;
    end;

    /// <summary>Asserts the item is not blocked unless allowBlocked is true.</summary>
    procedure AssertItemWritable(Item: Record Item; AllowBlocked: Boolean)
    begin
        Item.SetLoadFields("No.", Blocked);
        if Item.Blocked and not AllowBlocked then
            Error(ItemBlockedErr, Item."No.");
    end;

    /// <summary>Resolves a single item for Create/Update (subject / data keys). Errors if none.</summary>
    procedure ResolveSingleItem(var Argument: Record "Message Argument ori"; var Item: Record Item): Boolean
    var
        DocumentLookup: Codeunit "Document Lookup ori";
        ItemExpectedLbl: Label 'an existing item', Comment = 'is-IS=fyrirliggjandi vara';
        ItemNextLbl: Label 'Send an item identifier or filter matching an existing item.', Comment = 'is-IS=Sendu vöruauðkenni eða síu sem passar við fyrirliggjandi vöru.';
    begin
        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        if not DocumentLookup.FindItemRange(Argument, Item) then
            exit(false);
        if not Item.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NoItemsErr, 'itemNo', '', ItemExpectedLbl, ItemNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Reads attributes array from request data; errors if missing/empty.</summary>
    procedure GetAttributesArray(RequestJson: JsonObject; var AttributesArray: JsonArray)
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get('attributes', Token) or not Token.IsArray() then
            Error(AttributesRequiredErr);
        AttributesArray := Token.AsArray();
        if AttributesArray.Count() = 0 then
            Error(AttributesRequiredErr);
    end;

    /// <summary>Gets a boolean from JSON with default.</summary>
    procedure GetBool(Object: JsonObject; KeyName: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        if Object.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(DefaultValue);
    end;

    /// <summary>Gets text from JSON object key.</summary>
    procedure GetText(Object: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Object.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    /// <summary>Gets integer from JSON object key.</summary>
    procedure GetInteger(Object: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if Object.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    /// <summary>Gets decimal from JSON object key.</summary>
    procedure GetDecimal(Object: JsonObject; KeyName: Text; var Value: Decimal): Boolean
    var
        Token: JsonToken;
    begin
        if Object.Get(KeyName, Token) and Token.IsValue() then begin
            Value := Token.AsValue().AsDecimal();
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>Gets date from JSON (format 9) object key.</summary>
    procedure GetDate(Object: JsonObject; KeyName: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        DateText: Text;
    begin
        if Object.Get(KeyName, Token) and Token.IsValue() then begin
            DateText := Token.AsValue().AsText();
            if Evaluate(Value, DateText, 9) then
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Ensures an Item Attribute Value row exists for the requested typed value.
    /// For Option, looks up by Value name; creates when createValueIfMissing.
    /// For non-Option, finds or creates a value carrying the typed fields.
    /// </summary>
    procedure EnsureAttributeValue(ItemAttribute: Record "Item Attribute"; AttrRequest: JsonObject; CreateValueIfMissing: Boolean; var ItemAttributeValue: Record "Item Attribute Value")
    var
        ValueText: Text;
        NumericValue: Decimal;
        DateValue: Date;
        HasNumeric: Boolean;
        HasDate: Boolean;
    begin
        ValueText := GetText(AttrRequest, 'value');
        HasNumeric := GetDecimal(AttrRequest, 'numericValue', NumericValue);
        HasDate := GetDate(AttrRequest, 'dateValue', DateValue);

        case ItemAttribute.Type of
            ItemAttribute.Type::Option:
                begin
                    if ValueText = '' then
                        Error(ValueRequiredErr, ItemAttribute.Name);
                    ItemAttributeValue.Reset();
                    ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value");
                    ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
                    ItemAttributeValue.SetRange(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
                    if ItemAttributeValue.FindFirst() then
                        exit;
                    if not CreateValueIfMissing then
                        Error(OptionValueMissingErr, ValueText, ItemAttribute.Name);
                    Clear(ItemAttributeValue);
                    ItemAttributeValue.Init();
                    ItemAttributeValue."Attribute ID" := ItemAttribute.ID;
                    ItemAttributeValue.ID := 0;
                    ItemAttributeValue.Validate(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
                    ItemAttributeValue.Insert(true);
                end;
            ItemAttribute.Type::Text:
                begin
                    if ValueText = '' then
                        Error(ValueRequiredErr, ItemAttribute.Name);
                    FindOrCreateTextValue(ItemAttribute, ValueText, ItemAttributeValue);
                end;
            ItemAttribute.Type::Integer, ItemAttribute.Type::Decimal:
                begin
                    if not HasNumeric then
                        if ValueText <> '' then
                            if not Evaluate(NumericValue, ValueText, 9) then
                                Error(ValueRequiredErr, ItemAttribute.Name)
                            else
                                HasNumeric := true;
                    if not HasNumeric then
                        Error(ValueRequiredErr, ItemAttribute.Name);
                    FindOrCreateNumericValue(ItemAttribute, NumericValue, ItemAttributeValue);
                end;
            ItemAttribute.Type::Date:
                begin
                    if not HasDate then
                        if ValueText <> '' then
                            if not Evaluate(DateValue, ValueText, 9) then
                                Error(ValueRequiredErr, ItemAttribute.Name)
                            else
                                HasDate := true;
                    if not HasDate then
                        Error(ValueRequiredErr, ItemAttribute.Name);
                    FindOrCreateDateValue(ItemAttribute, DateValue, ItemAttributeValue);
                end;
        end;
    end;

    local procedure FindOrCreateTextValue(ItemAttribute: Record "Item Attribute"; ValueText: Text; var ItemAttributeValue: Record "Item Attribute Value")
    begin
        ItemAttributeValue.Reset();
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value");
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        ItemAttributeValue.SetRange(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
        if ItemAttributeValue.FindFirst() then
            exit;
        Clear(ItemAttributeValue);
        ItemAttributeValue.Init();
        ItemAttributeValue."Attribute ID" := ItemAttribute.ID;
        ItemAttributeValue.ID := 0;
        ItemAttributeValue.Validate(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
        ItemAttributeValue.Insert(true);
    end;

    local procedure FindOrCreateNumericValue(ItemAttribute: Record "Item Attribute"; NumericValue: Decimal; var ItemAttributeValue: Record "Item Attribute Value")
    begin
        ItemAttributeValue.Reset();
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value");
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        ItemAttributeValue.SetRange("Numeric Value", NumericValue);
        if ItemAttributeValue.FindFirst() then
            exit;
        Clear(ItemAttributeValue);
        ItemAttributeValue.Init();
        ItemAttributeValue."Attribute ID" := ItemAttribute.ID;
        ItemAttributeValue.ID := 0;
        ItemAttributeValue.Validate("Numeric Value", NumericValue);
        ItemAttributeValue.Insert(true);
    end;

    local procedure FindOrCreateDateValue(ItemAttribute: Record "Item Attribute"; DateValue: Date; var ItemAttributeValue: Record "Item Attribute Value")
    begin
        ItemAttributeValue.Reset();
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value");
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        ItemAttributeValue.SetRange("Date Value", DateValue);
        if ItemAttributeValue.FindFirst() then
            exit;
        Clear(ItemAttributeValue);
        ItemAttributeValue.Init();
        ItemAttributeValue."Attribute ID" := ItemAttribute.ID;
        ItemAttributeValue.ID := 0;
        ItemAttributeValue.Validate("Date Value", DateValue);
        ItemAttributeValue.Insert(true);
    end;

    /// <summary>Creates or updates a mapping for Create semantics (conflict/overwrite/idempotent).</summary>
    procedure AssignMapping(Item: Record Item; ItemAttribute: Record "Item Attribute"; ItemAttributeValue: Record "Item Attribute Value"; Overwrite: Boolean; var Changed: Boolean; var ResultJson: JsonObject)
    var
        Mapping: Record "Item Attribute Value Mapping";
        ExistingValue: Record "Item Attribute Value";
        CurrentDisplay: Text;
    begin
        Changed := false;
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        if Mapping.Get(Database::Item, Item."No.", ItemAttribute.ID) then begin
            if Mapping."Item Attribute Value ID" = ItemAttributeValue.ID then begin
                ResultJson.Add('attributeName', ItemAttribute.Name);
                ResultJson.Add('value', ItemAttributeValue.Value);
                ResultJson.Add('changed', false);
                ResultJson.Add('attributeId', ItemAttribute.ID);
                ResultJson.Add('valueId', ItemAttributeValue.ID);
                exit;
            end;
            if ExistingValue.Get(ItemAttribute.ID, Mapping."Item Attribute Value ID") then
                CurrentDisplay := ExistingValue.Value;
            if not Overwrite then
                Error(MappingConflictErr, Item."No.", ItemAttribute.Name);
            Mapping.Validate("Item Attribute Value ID", ItemAttributeValue.ID);
            Mapping.Modify(true);
            Changed := true;
            ResultJson.Add('attributeName', ItemAttribute.Name);
            ResultJson.Add('value', ItemAttributeValue.Value);
            ResultJson.Add('changed', true);
            ResultJson.Add('attributeId', ItemAttribute.ID);
            ResultJson.Add('valueId', ItemAttributeValue.ID);
            ResultJson.Add('before', CurrentDisplay);
            exit;
        end;

        Mapping.Init();
        Mapping."Table ID" := Database::Item;
        Mapping."No." := Item."No.";
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ItemAttributeValue.ID);
        Mapping.Insert(true);
        Changed := true;
        ResultJson.Add('attributeName', ItemAttribute.Name);
        ResultJson.Add('value', ItemAttributeValue.Value);
        ResultJson.Add('changed', true);
        ResultJson.Add('attributeId', ItemAttribute.ID);
        ResultJson.Add('valueId', ItemAttributeValue.ID);
    end;

    /// <summary>Updates an existing mapping; errors if missing.</summary>
    procedure UpdateMapping(Item: Record Item; ItemAttribute: Record "Item Attribute"; ItemAttributeValue: Record "Item Attribute Value"; var ResultJson: JsonObject)
    var
        Mapping: Record "Item Attribute Value Mapping";
        ExistingValue: Record "Item Attribute Value";
        BeforeText: Text;
    begin
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        if not Mapping.Get(Database::Item, Item."No.", ItemAttribute.ID) then
            Error(MappingMissingErr, Item."No.", ItemAttribute.Name);
        if ExistingValue.Get(ItemAttribute.ID, Mapping."Item Attribute Value ID") then
            BeforeText := ExistingValue.Value;
        Mapping.Validate("Item Attribute Value ID", ItemAttributeValue.ID);
        Mapping.Modify(true);
        ResultJson.Add('attributeName', ItemAttribute.Name);
        ResultJson.Add('before', BeforeText);
        ResultJson.Add('after', ItemAttributeValue.Value);
        ResultJson.Add('attributeId', ItemAttribute.ID);
        ResultJson.Add('valueId', ItemAttributeValue.ID);
    end;

    /// <summary>Creates a new Item Attribute definition (+ option values).</summary>
    procedure CreateDefinition(RequestJson: JsonObject; var ResponseJson: JsonObject)
    var
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        NameText: Text;
        TypeText: Text;
        UnitText: Text;
        OptionToken: JsonToken;
        OptionArray: JsonArray;
        OptionValueToken: JsonToken;
        CreatedValues: JsonArray;
        CreatedValueJson: JsonObject;
        OptionValueText: Text;
        i: Integer;
    begin
        NameText := GetText(RequestJson, 'name');
        if NameText = '' then
            Error(NameRequiredErr);
        TypeText := GetText(RequestJson, 'type');
        if TypeText = '' then
            Error(TypeRequiredErr);

        ItemAttribute.Reset();
        ItemAttribute.SetRange(Name, CopyStr(NameText, 1, MaxStrLen(ItemAttribute.Name)));
        if not ItemAttribute.IsEmpty() then
            Error(DuplicateAttributeErr, NameText);

        UnitText := GetText(RequestJson, 'unitOfMeasure');

        ItemAttribute.Init();
        if not TryParseType(TypeText, ItemAttribute) then
            Error(UnknownTypeErr, TypeText);
        ItemAttribute.Validate(Name, CopyStr(NameText, 1, MaxStrLen(ItemAttribute.Name)));
        ItemAttribute.Validate(Type, ItemAttribute.Type);
        if UnitText <> '' then
            ItemAttribute.Validate("Unit of Measure", CopyStr(UnitText, 1, MaxStrLen(ItemAttribute."Unit of Measure")));
        ItemAttribute.Insert(true);

        if (ItemAttribute.Type = ItemAttribute.Type::Option) and RequestJson.Get('optionValues', OptionToken) and OptionToken.IsArray() then begin
            OptionArray := OptionToken.AsArray();
            for i := 0 to OptionArray.Count() - 1 do begin
                OptionArray.Get(i, OptionValueToken);
                if OptionValueToken.IsValue() then begin
                    OptionValueText := OptionValueToken.AsValue().AsText();
                    Clear(ItemAttributeValue);
                    ItemAttributeValue.Init();
                    ItemAttributeValue."Attribute ID" := ItemAttribute.ID;
                    ItemAttributeValue.ID := 0;
                    ItemAttributeValue.Validate(Value, CopyStr(OptionValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
                    ItemAttributeValue.Insert(true);
                    Clear(CreatedValueJson);
                    CreatedValueJson.Add('valueId', ItemAttributeValue.ID);
                    CreatedValueJson.Add('value', ItemAttributeValue.Value);
                    CreatedValues.Add(CreatedValueJson);
                end;
            end;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('attributeId', ItemAttribute.ID);
        ResponseJson.Add('attributeName', ItemAttribute.Name);
        ResponseJson.Add('type', TypeName(ItemAttribute));
        ResponseJson.Add('createdValues', CreatedValues);
    end;

    /// <summary>Resolves attribute from one attributes[] element; validates optional type.</summary>
    procedure ResolveAttributeFromRequest(AttrRequest: JsonObject; var ItemAttribute: Record "Item Attribute")
    var
        Probe: Record "Item Attribute";
        AttributeId: Integer;
        AttributeName: Text;
        TypeText: Text;
    begin
        AttributeId := GetInteger(AttrRequest, 'attributeId');
        AttributeName := GetText(AttrRequest, 'name');
        if AttributeName = '' then
            AttributeName := GetText(AttrRequest, 'attributeName');
        if not FindAttribute(AttributeId, AttributeName, ItemAttribute) then
            Error(AttributeNotFoundErr, AttributeName);
        TypeText := GetText(AttrRequest, 'type');
        if TypeText <> '' then
            if TryParseType(TypeText, Probe) then
                if ItemAttribute.Type <> Probe.Type then
                    Error(AttributeTypeMismatchErr, ItemAttribute.Name, TypeName(ItemAttribute), TypeText);
    end;

    /// <summary>Parses attributeNames / attributeIds filters from Get request.</summary>
    procedure ParseGetFilters(RequestJson: JsonObject; var NameFilter: List of [Text]; var IdFilter: List of [Integer]; var IncludeUnassigned: Boolean)
    var
        Token: JsonToken;
        Arr: JsonArray;
        Elem: JsonToken;
        i: Integer;
    begin
        IncludeUnassigned := GetBool(RequestJson, 'includeUnassigned', false);
        if RequestJson.Get('attributeNames', Token) and Token.IsArray() then begin
            Arr := Token.AsArray();
            for i := 0 to Arr.Count() - 1 do begin
                Arr.Get(i, Elem);
                if Elem.IsValue() then
                    NameFilter.Add(Elem.AsValue().AsText());
            end;
        end;
        if RequestJson.Get('attributeIds', Token) and Token.IsArray() then begin
            Arr := Token.AsArray();
            for i := 0 to Arr.Count() - 1 do begin
                Arr.Get(i, Elem);
                if Elem.IsValue() then
                    IdFilter.Add(Elem.AsValue().AsInteger());
            end;
        end;
    end;
    var
        NoItemsErr: Label 'No items found matching the specified criteria.', Comment = 'is-IS=Engar vörur fundust sem passa við tilgreind skilyrði.';
}
