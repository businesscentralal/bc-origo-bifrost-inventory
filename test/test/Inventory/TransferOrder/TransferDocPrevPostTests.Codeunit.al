namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.PreviewPost message type.
/// </summary>
codeunit 96912 "Transfer Doc Prev. Post Tests"
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
    procedure PreviewPost_ShipReleased_ReturnsPreviewAndRollsBack()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader, AfterTransferHeader : Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, PredictedToken : JsonToken;
        LastShipmentNoBefore: Code[20];
    begin
        // [SCENARIO] PreviewPost returns predicted numbers and does not actually post
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        TransferHeader.Get(TransferHeader."No.");
        LastShipmentNoBefore := TransferHeader."Last Shipment No.";

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.PreviewPost", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('predictedNumbers', PredictedToken), 'predictedNumbers missing');

        // [THEN] Transfer header should NOT have changed (preview rolled back)
        AfterTransferHeader.Get(TransferHeader."No.");
        Assert.AreEqual(LastShipmentNoBefore, AfterTransferHeader."Last Shipment No.", 'Preview should not have changed Last Shipment No.');
    end;

    [Test]
    procedure PreviewPost_NothingToShip_ReturnsNothingToPreview()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        RequestJson, ResponseJson : JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] #140 AC5: a released transfer order with nothing to ship never previews as Success.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Ship", 0);
        TransferLine.Modify(true);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.PreviewPost", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Never Success when nothing would be shipped');
        Assert.IsTrue(ResponseJson.Get('code', Token), 'code missing');
        Assert.AreEqual('NothingToPreview', Token.AsValue().AsText(), 'code');
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing');
        Assert.IsTrue(Token.AsValue().AsText().Contains('Inventory.TransferOrder.Statistics'), 'nextStep names the Statistics type');
    end;
}
