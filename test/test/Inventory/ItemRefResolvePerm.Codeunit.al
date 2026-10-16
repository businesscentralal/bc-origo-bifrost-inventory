namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.ItemReference.Resolve denies a caller who cannot read item references.
/// </summary>
codeunit 96923 "Item Ref. Resolve Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutInvRead_ReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        ResolveImpl: Codeunit "Item Ref. Resolve Impl ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        LibraryLowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
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
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'BIFROST InvRead ori'), NextStepToken.AsValue().AsText());
    end;
}
