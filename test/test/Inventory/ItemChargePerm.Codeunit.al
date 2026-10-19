namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemCharge.Assign and Get deny a caller without the inventory permission sets.
/// </summary>
codeunit 96955 "Item Charge Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutInvWrite_AssignReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        AssignImpl: Codeunit "Item Charge Assign Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsFalse(AssignImpl.IsEnabled(), 'Assign should be disabled without write permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', 10000);
        RequestJson.Add('method', 'equally');
        TempArgument.SetRequestJson(RequestJson);
        AssignImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'BIFROST InvWrite ori'), NextStepToken.AsValue().AsText());
    end;

    [Test]
    procedure WithoutInvRead_GetReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        GetImpl: Codeunit "Item Charge Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsFalse(GetImpl.IsEnabled(), 'Get should be disabled without read permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('documentType', 'purchase');
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', 10000);
        TempArgument.SetRequestJson(RequestJson);
        GetImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'BIFROST InvRead ori'), NextStepToken.AsValue().AsText());
    end;
}
