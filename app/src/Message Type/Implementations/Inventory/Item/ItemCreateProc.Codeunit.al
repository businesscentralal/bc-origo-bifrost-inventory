namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.Item.Create, run through Codeunit.Run so a failure rolls back and answers a
/// clean error. Validation in the Impl has already refused bad requests.
/// </summary>
codeunit 10076931 "Item Create Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Item: Record Item;
        RequestJson: JsonObject;
        TemplateCode: Code[20];
    begin
        RequestJson := Rec.GetRequestJson();
        TemplateCode := CopyStr(ReadText(RequestJson, 'templateCode'), 1, MaxStrLen(TemplateCode));
        CreateFromTemplate(Item, TemplateCode);
        ApplyRequest(Item, RequestJson);
        Rec.SetResponseJson(BuildResponse(Item, TemplateCode));
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure CreateFromTemplate(var Item: Record Item; TemplateCode: Code[20])
    var
        ItemTemplMgt: Codeunit "Item Templ. Mgt.";
        IsHandled: Boolean;
        NotCreatedErr: Label 'Business Central did not create an item from template %1.', Comment = '%1 = template code, is-IS=Business Central stofnaði ekki vöru út frá sniðmáti %1.';
    begin
        if not ItemTemplMgt.CreateItemFromTemplate(Item, IsHandled, TemplateCode) then
            Error(NotCreatedErr, TemplateCode);
    end;

    local procedure ApplyRequest(var Item: Record Item; RequestJson: JsonObject)
    var
        Token: JsonToken;
        Changed: Boolean;
    begin
        if RequestJson.Contains('description') then begin
            Item.Validate(Description, CopyStr(ReadText(RequestJson, 'description'), 1, MaxStrLen(Item.Description)));
            Changed := true;
        end;
        if ReadText(RequestJson, 'baseUnitOfMeasure') <> '' then begin
            Item.Validate("Base Unit of Measure", CopyStr(ReadText(RequestJson, 'baseUnitOfMeasure'), 1, MaxStrLen(Item."Base Unit of Measure")));
            Changed := true;
        end;
        if RequestJson.Get('unitPrice', Token) then begin
            Item.Validate("Unit Price", Token.AsValue().AsDecimal());
            Changed := true;
        end;
        if RequestJson.Contains('gtin') then begin
            Item.Validate(GTIN, CopyStr(ReadText(RequestJson, 'gtin'), 1, MaxStrLen(Item.GTIN)));
            Changed := true;
        end;
        if Changed then
            Item.Modify(true);
    end;

    local procedure BuildResponse(Item: Record Item; TemplateCode: Code[20]) ResponseJson: JsonObject
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        Units: JsonArray;
        UnitJson: JsonObject;
    begin
        Item.Get(Item."No.");
        ItemUnitOfMeasure.SetLoadFields("Item No.", Code, "Qty. per Unit of Measure");
        ItemUnitOfMeasure.SetRange("Item No.", Item."No.");
        if ItemUnitOfMeasure.FindSet() then
            repeat
                Clear(UnitJson);
                UnitJson.Add('code', ItemUnitOfMeasure.Code);
                UnitJson.Add('qtyPerUnitOfMeasure', ItemUnitOfMeasure."Qty. per Unit of Measure");
                Units.Add(UnitJson);
            until ItemUnitOfMeasure.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('templateCode', TemplateCode);
        ResponseJson.Add('description', Item.Description);
        ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        ResponseJson.Add('unitPrice', Item."Unit Price");
        ResponseJson.Add('gtin', Item.GTIN);
        ResponseJson.Add('unitsOfMeasure', Units);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if (not Token.IsValue()) or Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
