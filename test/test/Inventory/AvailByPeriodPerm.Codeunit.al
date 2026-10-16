namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.AvailabilityByPeriod.Get denies a caller who cannot read items.
/// BIFROST Read ori includes the InvRead extension, which grants Item, so this test keeps the caller on no permission set.
/// </summary>
codeunit 96925 "Avail. By Period Perm"
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
        AvailImpl: Codeunit "Avail. By Period Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsFalse(AvailImpl.IsEnabled(), 'Availability by period should be disabled without item read');

        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('itemNo', 'ANY');
        RequestJson.Add('periodType', 'month');
        RequestJson.Add('from', '2026-10-16');
        RequestJson.Add('periods', 1);
        TempArgument.SetRequestJson(RequestJson);

        AvailImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'BIFROST InvRead ori'), NextStepToken.AsValue().AsText());
    end;
}
