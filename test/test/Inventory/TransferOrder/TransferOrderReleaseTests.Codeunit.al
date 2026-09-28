namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Release message type.
/// </summary>
codeunit 96915 "Transfer Order Release Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then exit;
        IsInitialized := true;
    end;

    [Test]
    procedure Release_OpenOrder_StatusChangesToReleased()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, StatusAfterToken : JsonToken;
    begin
        // [SCENARIO] Releasing an open order moves it to Released
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Release", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('statusAfter', StatusAfterToken), 'statusAfter missing');
        Assert.AreEqual('Released', StatusAfterToken.AsValue().AsText(), 'statusAfter should be Released');

        TransferHeader.Get(TransferHeader."No.");
        Assert.AreEqual(TransferHeader.Status::Released, TransferHeader.Status, 'Header should be Released');
    end;

    [Test]
    procedure Release_AlreadyReleased_NoOp()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, StatusBeforeToken, StatusAfterToken : JsonToken;
    begin
        // [SCENARIO] Releasing an already-released order returns Success with no change
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 5);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Release", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('statusBefore', StatusBeforeToken), 'statusBefore missing');
        Assert.IsTrue(ResponseJson.Get('statusAfter', StatusAfterToken), 'statusAfter missing');
        Assert.AreEqual('Released', StatusBeforeToken.AsValue().AsText(), 'statusBefore should be Released');
        Assert.AreEqual('Released', StatusAfterToken.AsValue().AsText(), 'statusAfter should be Released');
    end;
}
