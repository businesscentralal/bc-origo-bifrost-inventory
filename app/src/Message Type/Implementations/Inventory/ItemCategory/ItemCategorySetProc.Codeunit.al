namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.ItemCategory.Set. Validation has already refused bad requests.
/// </summary>
codeunit 70013499 "Item Category Set Proc ori"
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
    begin
        RequestJson := Rec.GetRequestJson();
        CategoryCode := SaveCategory(RequestJson);
        ApplyAttributes(RequestJson, CategoryCode);
        ItemCategory.Get(CategoryCode);
        ResponseJson := GetImpl.BuildCategoryJson(ItemCategory, true);
        ResponseJson.Add('status', 'Success');
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure SaveCategory(RequestJson: JsonObject) CategoryCode: Code[20]
    var
        ItemCategory: Record "Item Category";
        CategoryId: Guid;
        DescriptionText: Text;
        ParentCode: Code[20];
    begin
        if RequestJson.Contains('systemId') then begin
            Evaluate(CategoryId, ReadText(RequestJson, 'systemId'));
            ItemCategory.GetBySystemId(CategoryId);
        end else begin
            CategoryCode := CopyStr(ReadText(RequestJson, 'code'), 1, MaxStrLen(ItemCategory.Code));
            if not ItemCategory.Get(CategoryCode) then
                ItemCategory.Init();
        end;
        if ItemCategory.Code = '' then begin
            ItemCategory.Validate(Code, CategoryCode);
            if RequestJson.Contains('description') then begin
                DescriptionText := ReadText(RequestJson, 'description');
                ItemCategory.Validate(Description, CopyStr(DescriptionText, 1, MaxStrLen(ItemCategory.Description)));
            end;
            if RequestJson.Contains('parentCategory') then begin
                ParentCode := CopyStr(ReadText(RequestJson, 'parentCategory'), 1, MaxStrLen(ItemCategory."Parent Category"));
                if ParentCode <> '' then
                    ItemCategory.Validate("Parent Category", ParentCode);
            end;
            // OnInsert calls OnPrem UpdateIndentationTree and CalcPresentationOrder, which abort the transaction in this sandbox.
            SetTreePosition(ItemCategory);
            ItemCategory."Last Modified Date Time" := CurrentDateTime();
            ItemCategory.Insert(false);
        end else
            if RequestJson.Contains('description') then begin
                DescriptionText := ReadText(RequestJson, 'description');
                ItemCategory.Validate(Description, CopyStr(DescriptionText, 1, MaxStrLen(ItemCategory.Description)));
                ItemCategory."Last Modified Date Time" := CurrentDateTime();
                ItemCategory.Modify(false);
            end;
        CategoryCode := ItemCategory.Code;
    end;

    local procedure SetTreePosition(var ItemCategory: Record "Item Category")
    var
        ParentCategory: Record "Item Category";
        Sibling: Record "Item Category";
        ParentCode: Code[20];
        Level: Integer;
    begin
        ParentCode := ItemCategory."Parent Category";
        Level := 0;
        while (ParentCode <> '') and ParentCategory.Get(ParentCode) and (Level < 100) do begin
            Level += 1;
            ParentCode := ParentCategory."Parent Category";
        end;
        ItemCategory.Indentation := Level;
        ItemCategory."Has Children" := false;
        if ItemCategory."Parent Category" <> '' then
            if ParentCategory.Get(ItemCategory."Parent Category") then
                if not ParentCategory."Has Children" then begin
                    ParentCategory."Has Children" := true;
                    ParentCategory.Modify(false);
                end;
        Sibling.SetCurrentKey("Presentation Order");
        Sibling.SetRange("Parent Category", ItemCategory."Parent Category");
        if Sibling.FindLast() then
            ItemCategory."Presentation Order" := Sibling."Presentation Order" + 10000
        else
            ItemCategory."Presentation Order" := 10000;
    end;

    local procedure ApplyAttributes(RequestJson: JsonObject; CategoryCode: Code[20])
    var
        Attributes: JsonArray;
        AttributeToken: JsonToken;
        AttributeJson: JsonObject;
        Index: Integer;
    begin
        if not ReadArray(RequestJson, 'attributes', Attributes) then
            exit;
        for Index := 0 to Attributes.Count() - 1 do begin
            Attributes.Get(Index, AttributeToken);
            AttributeJson := AttributeToken.AsObject();
            ApplyOneAttribute(CategoryCode, AttributeJson);
        end;
    end;

    local procedure ApplyOneAttribute(CategoryCode: Code[20]; AttributeJson: JsonObject)
    var
        ItemAttribute: Record "Item Attribute";
        ItemAttributeValue: Record "Item Attribute Value";
        Mapping: Record "Item Attribute Value Mapping";
        AncestorValueId: Integer;
    begin
        FindAttribute(AttributeJson, ItemAttribute);
        FindValue(ItemAttribute, ReadText(AttributeJson, 'value'), ItemAttributeValue);
        AncestorValueId := FindAncestorValueId(CategoryCode, ItemAttribute.ID);
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        if (AncestorValueId <> 0) and (AncestorValueId = ItemAttributeValue.ID) then begin
            if Mapping.Get(Database::"Item Category", CategoryCode, ItemAttribute.ID) then
                Mapping.Delete(true);
            exit;
        end;
        if Mapping.Get(Database::"Item Category", CategoryCode, ItemAttribute.ID) then begin
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
        CurrentCode: Code[20];
        Steps: Integer;
    begin
        ItemCategory.SetLoadFields(Code, "Parent Category");
        if not ItemCategory.Get(CategoryCode) then
            exit(0);
        CurrentCode := ItemCategory."Parent Category";
        Steps := 0;
        Mapping.SetLoadFields("Table ID", "No.", "Item Attribute ID", "Item Attribute Value ID");
        while (CurrentCode <> '') and (Steps < 100) do begin
            Steps += 1;
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
        AttributeName: Text;
    begin
        ItemAttribute.SetLoadFields(ID, Name, Type, Blocked);
        if AttributeJson.Contains('id') then begin
            ItemAttribute.Get(ReadInteger(AttributeJson, 'id'));
            exit;
        end;
        AttributeName := ReadText(AttributeJson, 'name');
        ItemAttribute.SetRange(Name, CopyStr(AttributeName, 1, MaxStrLen(ItemAttribute.Name)));
        ItemAttribute.FindFirst();
    end;

    local procedure FindValue(ItemAttribute: Record "Item Attribute"; ValueText: Text; var ItemAttributeValue: Record "Item Attribute Value")
    var
        NumericValue: Decimal;
        DateValue: Date;
    begin
        ItemAttributeValue.SetLoadFields("Attribute ID", ID, Value, "Numeric Value", "Date Value", Blocked);
        ItemAttributeValue.SetRange("Attribute ID", ItemAttribute.ID);
        case ItemAttribute.Type of
            ItemAttribute.Type::Integer, ItemAttribute.Type::Decimal:
                begin
                    Evaluate(NumericValue, ValueText);
                    ItemAttributeValue.SetRange("Numeric Value", NumericValue);
                end;
            ItemAttribute.Type::Date:
                begin
                    Evaluate(DateValue, ValueText);
                    ItemAttributeValue.SetRange("Date Value", DateValue);
                end;
            else
                ItemAttributeValue.SetRange(Value, CopyStr(ValueText, 1, MaxStrLen(ItemAttributeValue.Value)));
        end;
        ItemAttributeValue.FindFirst();
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
