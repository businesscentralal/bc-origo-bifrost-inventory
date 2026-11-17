namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Isolated write for Inventory.ItemVariant.Create, run through Codeunit.Run so a native failure rolls back and
/// answers a clean error. Validation in the Impl has already refused bad requests.
/// </summary>
codeunit 10076992 "Item Variant Create Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ItemVariant: Record "Item Variant";
        GetImpl: Codeunit "Item Variant Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson := Rec.GetRequestJson();
        ItemVariant.Init();
        ItemVariant.Validate("Item No.", CopyStr(ReadText(RequestJson, 'itemNo'), 1, MaxStrLen(ItemVariant."Item No.")));
        ItemVariant.Validate(Code, CopyStr(ReadText(RequestJson, 'code'), 1, MaxStrLen(ItemVariant.Code)));
        if RequestJson.Contains('description') then
            ItemVariant.Validate(Description, CopyStr(ReadText(RequestJson, 'description'), 1, MaxStrLen(ItemVariant.Description)));
        if RequestJson.Contains('description2') then
            ItemVariant.Validate("Description 2", CopyStr(ReadText(RequestJson, 'description2'), 1, MaxStrLen(ItemVariant."Description 2")));
        if RequestJson.Contains('blocked') then
            ItemVariant.Validate(Blocked, ReadBoolean(RequestJson, 'blocked'));
        ItemVariant.Insert(true);
        ItemVariant.Get(ItemVariant."Item No.", ItemVariant.Code);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('created', true);
        ResponseJson.Add('itemNo', ItemVariant."Item No.");
        ResponseJson.Add('variant', GetImpl.BuildVariantJson(ItemVariant));
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
}
