namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Shared helpers for Item Attribute message types: type-name mapping, name→id resolution,
/// value coercion, and JSON attribute object building. Reuses base-app
/// <c>Item Attribute Management</c> for mapping inserts where applicable.
/// </summary>
codeunit 10036908 "Item Attribute Resolve ori"
{
    Access = Internal;

    var
        AttributeNotFoundErr: Label 'Item attribute "%1" was not found.', Comment = '%1 = Attribute name or id', Locked = true;
        AttributeTypeMismatchErr: Label 'Attribute "%1" has type %2; request type %3 does not match.', Comment = '%1 = Name, %2 = Actual type, %3 = Requested type', Locked = true;
        OptionValueMissingErr: Label 'Option value "%1" was not found for attribute "%2". Pass createValueIfMissing: true to create it.', Comment = '%1 = Value, %2 = Attribute name', Locked = true;
        MappingConflictErr: Label 'Item "%1" already has attribute "%2" with a different value. Pass overwrite: true or use Item.Attribute.Update.', Comment = '%1 = Item No., %2 = Attribute name', Locked = true;
        MappingMissingErr: Label 'Item "%1" has no mapping for attribute "%2". Use Item.Attribute.Create first.', Comment = '%1 = Item No., %2 = Attribute name', Locked = true;
        ItemBlockedErr: Label 'Item "%1" is blocked. Pass allowBlocked: true to override.', Comment = '%1 = Item No.', Locked = true;
        AttributesRequiredErr: Label 'Request data.attributes must be a non-empty array.', Locked = true;
        NameRequiredErr: Label 'Attribute definition requires data.name.', Locked = true;
        TypeRequiredErr: Label 'Attribute definition requires data.type.', Comment = '', Locked = true;
        DuplicateAttributeErr: Label 'Item attribute "%1" already exists.', Comment = '%1 = Attribute name', Locked = true;
        UnknownTypeErr: Label 'Unknown attribute type "%1". Expected Option, Text, Integer, Decimal, or Date.', Comment = '%1 = Type name', Locked = true;
        ValueRequiredErr: Label 'A value is required for attribute "%1".', Comment = '%1 = Attribute name', Locked = true;

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
    begin
        Item.Reset();
        Item.SetLoadFields("No.", SystemId, Blocked, Type);
        if not Argument.FindItemRange(Item) then
            exit(false);
        if not Item.FindFirst() then begin
            Argument.RespondWithError('No items found matching the specified criteria.');
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
}
