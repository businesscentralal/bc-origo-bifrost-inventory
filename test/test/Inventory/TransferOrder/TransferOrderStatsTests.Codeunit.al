namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Statistics message type.
/// </summary>
codeunit 96917 "Transfer Order Stats. Tests"
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
    procedure Statistics_OrderWithTwoLines_ReturnsTotals()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson, TotalsObj : JsonObject;
        StatusToken, TotalsToken, LineCountToken, QtyToken : JsonToken;
    begin
        // [SCENARIO] Statistics returns line count and total quantity for a multi-line order
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 200);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 15);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Statistics", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('totals', TotalsToken), 'totals missing');
        TotalsObj := TotalsToken.AsObject();
        Assert.IsTrue(TotalsObj.Get('lineCount', LineCountToken), 'lineCount missing');
        Assert.AreEqual(2, LineCountToken.AsValue().AsInteger(), 'Should have 2 lines');
        Assert.IsTrue(TotalsObj.Get('quantity', QtyToken), 'quantity missing');
        Assert.AreEqual(25.0, QtyToken.AsValue().AsDecimal(), 'Total quantity should be 25');
    end;
}
