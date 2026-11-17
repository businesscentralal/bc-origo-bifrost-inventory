namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.ItemUnitOfMeasure.Create, run through Codeunit.Run so a native failure rolls back and
/// answers a clean error. Validation in the Impl has already refused bad requests.
/// </summary>
codeunit 10077013 "Item UoM Create Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        GetImpl: Codeunit "Item UoM Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson := Rec.GetRequestJson();
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure.Validate("Item No.", CopyStr(ReadText(RequestJson, 'itemNo'), 1, MaxStrLen(ItemUnitOfMeasure."Item No.")));
        ItemUnitOfMeasure.Validate(Code, CopyStr(ReadText(RequestJson, 'code'), 1, MaxStrLen(ItemUnitOfMeasure.Code)));
        ItemUnitOfMeasure.Validate("Qty. per Unit of Measure", ReadDecimal(RequestJson, 'qtyPerUnitOfMeasure'));
        if RequestJson.Contains('length') then
            ItemUnitOfMeasure.Validate(Length, ReadDecimal(RequestJson, 'length'));
        if RequestJson.Contains('width') then
            ItemUnitOfMeasure.Validate(Width, ReadDecimal(RequestJson, 'width'));
        if RequestJson.Contains('height') then
            ItemUnitOfMeasure.Validate(Height, ReadDecimal(RequestJson, 'height'));
        if RequestJson.Contains('weight') then
            ItemUnitOfMeasure.Validate(Weight, ReadDecimal(RequestJson, 'weight'));
        ItemUnitOfMeasure.Insert(true);
        ItemUnitOfMeasure.Get(ItemUnitOfMeasure."Item No.", ItemUnitOfMeasure.Code);
        Item.Get(ItemUnitOfMeasure."Item No.");
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('created', true);
        ResponseJson.Add('itemNo', ItemUnitOfMeasure."Item No.");
        ResponseJson.Add('unit', GetImpl.BuildUnitJson(ItemUnitOfMeasure, Item."Base Unit of Measure"));
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
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

    local procedure ReadDecimal(RequestJson: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(0);
        if not Token.IsValue() then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;
}
