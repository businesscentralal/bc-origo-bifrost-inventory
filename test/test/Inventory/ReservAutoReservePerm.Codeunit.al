namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// AutoReserve and OrderTracking.Get deny a caller without the reservation permission.
/// </summary>
codeunit 96931 "Reserv. AutoReserve Perm"
{
    Subtype = Test;
    TestPermissions = Restrictive;
    Permissions = tabledata "Message Argument ori" = RIMD;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WithoutInvWrite_AutoReserveReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        AutoImpl: Codeunit "Reserv. AutoReserve Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(AutoImpl.IsEnabled(), 'AutoReserve should be disabled without write permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('documentType', 'Order');
        RequestJson.Add('documentNo', 'X');
        RequestJson.Add('lineNo', 10000);
        TempArgument.SetRequestJson(RequestJson);
        AutoImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'BIFROST InvWrite ori'), ReadText(ResponseJson, 'nextStep'));
    end;

    [Test]
    procedure WithoutInvRead_OrderTrackingReturnsPermissionDenied()
    var
        TempArgument: Record "Message Argument ori" temporary;
        TrackImpl: Codeunit "Order Tracking Get Impl ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        Assert.IsFalse(TrackImpl.IsEnabled(), 'OrderTracking should be disabled without the inventory read permission');
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        RequestJson.Add('sourceKind', 'Sales');
        RequestJson.Add('documentNo', 'X');
        RequestJson.Add('lineNo', 10000);
        TempArgument.SetRequestJson(RequestJson);
        TrackImpl.ExecuteBifrostTask(TempArgument);
        ResponseJson := TempArgument.GetResponseJson();
        Assert.AreEqual('PermissionDenied', ReadText(ResponseJson, 'code'), 'code');
        Assert.AreNotEqual(0, StrPos(ReadText(ResponseJson, 'nextStep'), 'BIFROST InvRead ori'), ReadText(ResponseJson, 'nextStep'));
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
