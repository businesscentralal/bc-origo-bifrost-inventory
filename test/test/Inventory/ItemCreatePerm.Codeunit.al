namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.Item.Create denies a caller who cannot create items (#130 AC04).
/// </summary>
codeunit 96961 "Item Create Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutItemWrite_CreateReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        CreateImpl: Codeunit "Item Create Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(CreateImpl.IsEnabled(), 'Create should be disabled without write permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('templateCode', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        CreateImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'the Bifrost "Full Access" permission set with Inventory write permissions'), ReadText(ResponseJson, 'nextStep'));
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
