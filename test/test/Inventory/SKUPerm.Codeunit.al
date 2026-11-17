namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.SKU.Get denies a caller without read permission and Inventory.SKU.Create a caller without write permission (#114 AC04).
/// </summary>
codeunit 96999 "SKU Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutPermission_GetReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        GetImpl: Codeunit "SKU Get Impl ori";
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(GetImpl.IsEnabled(), 'Get should be disabled without read permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(ResponseJson);
        GetImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
    end;

    [Test]
    procedure WithoutPermission_CreateReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        CreateImpl: Codeunit "SKU Create Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(CreateImpl.IsEnabled(), 'Create should be disabled without write permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('itemFilter', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        CreateImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
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
