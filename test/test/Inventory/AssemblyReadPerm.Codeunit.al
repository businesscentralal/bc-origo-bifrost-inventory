namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Inventory.AssemblyToOrder.Get and Inventory.AssemblyBOM.Get deny a caller who cannot read their tables (#116).
/// </summary>
codeunit 96967 "Assembly Read Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AsmToOrder_WithoutRead_ReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        AtoImpl: Codeunit "Asm. To Order Get Impl ori";
        RequestJson: JsonObject;
    begin
        Assert.IsFalse(AtoImpl.IsEnabled(), 'Assemble-to-order read should be disabled without read permissions');
        InitArgument(TempArgument);
        RequestJson.Add('documentNo', 'ANY');
        RequestJson.Add('lineNo', 10000);
        TempArgument.SetRequestJson(RequestJson);
        AtoImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument.GetResponseJson());
    end;

    [Test]
    procedure Bom_WithoutRead_ReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        BomImpl: Codeunit "Assembly BOM Get Impl ori";
        RequestJson: JsonObject;
    begin
        Assert.IsFalse(BomImpl.IsEnabled(), 'Assembly BOM read should be disabled without read permissions');
        InitArgument(TempArgument);
        RequestJson.Add('itemNo', 'ANY');
        TempArgument.SetRequestJson(RequestJson);
        BomImpl.ExecuteBifrostTask(TempArgument);
        AssertPermissionDenied(TempArgument.GetResponseJson());
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary)
    begin
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
    end;

    local procedure AssertPermissionDenied(ResponseJson: JsonObject)
    var
        CodeToken: JsonToken;
        NextStepToken: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get('code', CodeToken), 'code missing');
        Assert.AreEqual('PermissionDenied', CodeToken.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', NextStepToken), 'nextStep missing');
        Assert.AreNotEqual(0, StrPos(NextStepToken.AsValue().AsText(), 'the Bifrost "Read-Only" permission set with Inventory read permissions'), NextStepToken.AsValue().AsText());
    end;
}
