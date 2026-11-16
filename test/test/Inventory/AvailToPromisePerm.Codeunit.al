namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.AvailableToPromise.Get denies a caller who cannot read items (#105).
/// </summary>
codeunit 96965 "Avail. To Promise Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutInvRead_ReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        PromiseImpl: Codeunit "Avail. To Promise Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsFalse(PromiseImpl.IsEnabled(), 'Available to promise should be disabled without item read');

        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('quantity', 1);
        RequestJson.Add('requestedDate', '2026-11-16');
        TempArgument.SetRequestJson(RequestJson);

        PromiseImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'the Bifrost "Read-Only" permission set with Inventory read permissions'), NextStepToken.AsValue().AsText());
    end;
}
