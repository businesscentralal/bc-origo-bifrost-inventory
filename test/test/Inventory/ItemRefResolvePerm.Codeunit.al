namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemReference.Resolve denies a caller who cannot read item references.
/// BIFROST Read ori includes the InvRead extension, which grants Item and Item Reference,
/// so this test keeps the caller on no permission set.
/// </summary>
codeunit 96951 "Item Ref. Resolve Perm"
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
        ResolveImpl: Codeunit "Item Ref. Resolve Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsFalse(ResolveImpl.IsEnabled(), 'Resolve should be disabled without item reference read');

        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('referenceNo', 'ANY');
        TempArgument.SetRequestJson(RequestJson);

        ResolveImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'the Bifrost "Read-Only" permission set with Inventory read permissions'), NextStepToken.AsValue().AsText());
    end;
}
