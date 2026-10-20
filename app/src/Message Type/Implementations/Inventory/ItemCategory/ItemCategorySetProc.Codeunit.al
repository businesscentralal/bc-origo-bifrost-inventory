namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.ItemCategory.Set, run through Codeunit.Run so a failure rolls back and
/// answers a clean error. Validation in the Impl has already refused bad requests.
/// </summary>
codeunit 10076872 "Item Category Set Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ItemCategory: Record "Item Category";
        GetImpl: Codeunit "Item Category Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CategoryCode: Code[20];
        Created: Boolean;
    begin
        RequestJson := Rec.GetRequestJson();
        CategoryCode := SaveCategory(RequestJson, Created);
        ApplyAttributes(RequestJson, CategoryCode);
        ItemCategory.SetLoadFields(Code, Description, "Parent Category", Indentation, "Presentation Order");
        ItemCategory.Get(CategoryCode);
        ResponseJson := GetImpl.BuildCategoryJson(ItemCategory, true);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('created', Created);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>
    /// Finds an existing value of an attribute from its text form. Integer and Decimal values are read
    /// culture-invariant (period as decimal separator), Date values as yyyy-mm-dd, other types by their text.
    /// </summary>
    /// <param name="ItemAttribute">The attribute; ID and Type must be loaded.</param>
    /// <param name="ValueText">The value as sent by the caller.</param>
    /// <param name="ItemAttributeValue">Receives the found value.</param>
    /// <returns>True when a value was found.</returns>
    procedure FindAttributeValue(ItemAttribute: Record "Item Attribute"; ValueText: Text; var ItemAttributeValue: Record "Item Attribute Value"): Boolean
    var
        NumericValue: Decimal;
        DateValue: Date;
    begin
        ItemAttributeValue.Reset();
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value", Blocked);
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        case ItemAttribute.Type of
            ItemAttribute.Type::Integer, ItemAttribute.Type::Decimal:
                begin
                    if not Evaluate(NumericValue, ValueText, 9) then
                        exit(false);
                    ItemAttributeValue.SetRange("Numeric Value", NumericValue);
                end;
            ItemAttribute.Type::Date:
                begin
                    if not Evaluate(DateValue, ValueText, 9) then
                        exit(false);
                    ItemAttributeValue.SetRange("Date Value", DateValue);
                end;
            else
                ItemAttributeValue.SetRange(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
        end;
        exit(ItemAttributeValue.FindFirst());
    end;

    local procedure SaveCategory(RequestJson: JsonObject; var Created: Boolean) CategoryCode: Code[20]
    var
        ItemCategory: Record "Item Category";
        CategoryId: Guid;
        ParentCode: Code[20];
    begin
        Created := false;
        if RequestJson.Contains('systemId') then begin
            Evaluate(CategoryId, ReadText(RequestJson, 'systemId'));
            ItemCategory.GetBySystemId(CategoryId);
        end else begin
            CategoryCode := CopyStr(ReadText(RequestJson, 'code'), 1, MaxStrLen(ItemCategory.Code));
            if not ItemCategory.Get(CategoryCode) then begin
                ItemCategory.Init();
                Created := true;
            end;
        end;
        if Created then begin
            ItemCategory.Validate(Code, CategoryCode);
            if RequestJson.Contains('description') then
                ItemCategory.Validate(Description, CopyStr(ReadText(RequestJson, 'description'), 1, MaxStrLen(ItemCategory.Description)));
            if RequestJson.Contains('parentCategory') then begin
                ParentCode := CopyStr(ReadText(RequestJson, 'parentCategory'), 1, MaxStrLen(ItemCategory."Parent Category"));
                if ParentCode <> '' then
                    ItemCategory.Validate("Parent Category", ParentCode);
            end;
            ItemCategory.Insert(true);
        end else
            if RequestJson.Contains('description') then begin
                ItemCategory.Validate(Description, CopyStr(ReadText(RequestJson, 'description'), 1, MaxStrLen(ItemCategory.Description)));
                ItemCategory.Modify(true);
            end;
        CategoryCode := ItemCategory.Code;
    end;

    local procedure ApplyAttributes(RequestJson: JsonObject; CategoryCode: Code[20])
    var
        Attributes: JsonArray;
        AttributeToken: JsonToken;
    begin
        if not ReadArray(RequestJson, 'attributes', Attributes) then
            exit;
        foreach AttributeToken in Attributes do
            ApplyOneAttribute(CategoryCode, AttributeToken.AsObject());
    end;

    local procedure ApplyOneAttribute(CategoryCode: Code[20]; AttributeJson: JsonObject)
    var
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        AncestorValueId: Integer;
        ValueMissingErr: Label 'The attribute value %1 does not exist.', Comment = '%1 = value, is-IS=Gildi eiginleikans %1 er ekki til.';
    begin
        FindAttribute(AttributeJson, ItemAttribute);
        if not FindAttributeValue(ItemAttribute, ReadText(AttributeJson, 'value'), ItemAttributeValue) then
            Error(ValueMissingErr, ReadText(AttributeJson, 'value'));
        AncestorValueId := FindAncestorValueId(CategoryCode, ItemAttribute.ID);
        if (AncestorValueId <> 0) and (AncestorValueId = ItemAttributeValue.ID) then begin
            // Equal to the inherited value: keep no own row, so the category goes on inheriting.
            if Mapping.Get(Database::"Item Category", CategoryCode, ItemAttribute.ID) then
                Mapping.Delete(true);
            exit;
        end;
        if Mapping.Get(Database::"Item Category", CategoryCode, ItemAttribute.ID) then begin
            if Mapping."Item Attribute Value ID" = ItemAttributeValue.ID then
                exit;
            Mapping.Validate("Item Attribute Value ID", ItemAttributeValue.ID);
            Mapping.Modify(true);
            exit;
        end;
        Mapping.Init();
        Mapping."Table ID" := Database::"Item Category";
        Mapping."No." := CategoryCode;
        Mapping."Item Attribute ID" := ItemAttribute.ID;
        Mapping.Validate("Item Attribute Value ID", ItemAttributeValue.ID);
        Mapping.Insert(true);
    end;

    local procedure FindAncestorValueId(CategoryCode: Code[20]; AttributeId: Integer): Integer
    var
        ItemCategory: Record "Item Category";
        Mapping: Record "Item Attribute Value Mapping";
        Visited: List of [Code[20]];
        CurrentCode: Code[20];
    begin
        ItemCategory.SetLoadFields(Code, "Parent Category");
        if not ItemCategory.Get(CategoryCode) then
            exit(0);
        CurrentCode := ItemCategory."Parent Category";
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        while CurrentCode <> '' do begin
            if Visited.Contains(CurrentCode) then
                exit(0);
            Visited.Add(CurrentCode);
            if Mapping.Get(Database::"Item Category", CurrentCode, AttributeId) then
                exit(Mapping."Item Attribute Value ID");
            if not ItemCategory.Get(CurrentCode) then
                exit(0);
            CurrentCode := ItemCategory."Parent Category";
        end;
        exit(0);
    end;

    local procedure FindAttribute(AttributeJson: JsonObject; var ItemAttribute: Record "Item Attribute")
    var
        Token: JsonToken;
        AttributeName: Text;
    begin
        ItemAttribute.SetLoadFields(ID, Name, Type, Blocked);
        if AttributeJson.Get('id', Token) then begin
            ItemAttribute.Get(Token.AsValue().AsInteger());
            exit;
        end;
        AttributeName := ReadText(AttributeJson, 'name');
        ItemAttribute.SetRange(Name, CopyStr(AttributeName, 1, MaxStrLen(ItemAttribute.Name)));
        ItemAttribute.FindFirst();
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
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
}
