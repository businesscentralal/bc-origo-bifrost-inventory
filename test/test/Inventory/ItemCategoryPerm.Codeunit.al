namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemCategory.Get denies a caller without read permission and Set a caller without write permission (AC08).
/// </summary>
codeunit 96957 "Item Category Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutInvRead_GetReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        GetImpl: Codeunit "Item Category Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(GetImpl.IsEnabled(), 'Get should be disabled without read permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('includeAttributes', true);
        TempArgument.SetRequestJson(RequestJson);
        GetImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'BIFROST InvRead ori'), ReadText(ResponseJson, 'nextStep'));
    end;

    [Test]
    procedure WithoutInvWrite_SetReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        SetImpl: Codeunit "Item Category Set Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(SetImpl.IsEnabled(), 'Set should be disabled without write permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('code', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        SetImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'BIFROST InvWrite ori'), ReadText(ResponseJson, 'nextStep'));
    end;

    local procedure ReadText(ResponseJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if ResponseJson.Get(KeyName, Token) and Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
