namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Post message type.
/// </summary>
codeunit 96914 "Transfer Order Post Tests"
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
    procedure Post_Ship_ReturnsPostedShipmentNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ShipmentToken : JsonToken;
    begin
        // [SCENARIO] Posting Ship on a released transfer returns postedShipmentNo
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.AreNotEqual('', ShipmentToken.AsValue().AsText(), 'postedShipmentNo should be populated');
    end;

    [Test]
    procedure Post_InvalidPostingType_ReturnsError()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Invalid postingType value returns Error
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Bogus');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [Test]
    procedure Post_DirectTransfer_ReceiptAndShipment_ReturnsBothDocuments()
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        OriginalSetup: Record "Inventory Setup";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ShipmentToken: JsonToken;
        ReceiptToken: JsonToken;
        ShipmentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Receipt and Shipment on a direct transfer posts the shipment and the receipt together.
        Initialize();
        Helper.SetDirectTransferPosting(false, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Ship", 4);
        TransferLine.Modify(true);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success');
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ShipmentNo := CopyStr(ShipmentToken.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ShipmentNo, 'postedShipmentNo should be populated');
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferShipmentHeader.Get(ShipmentNo), 'Posted transfer shipment should exist');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(TransferHeader."No."), 'A partial direct transfer should keep the order');
    end;

    [Test]
    procedure Post_Receive_Full_ReturnsPostedReceiptNoAfterHeaderDeleted()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken: JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Full Receive after Ship deletes the transfer order and still returns Success with postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Full receive must not return an error after the posting committed. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsFalse(TransferHeader.Get(DocumentNo), 'A full receive deletes the transfer order');
    end;

    [Test]
    procedure Post_Receive_Partial_KeepsOrderAndReturnsPostedReceiptNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken: JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Partial Receive after Ship keeps the transfer order and returns postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        TransferLine.SetRange("Document No.", DocumentNo);
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Receive", 4);
        TransferLine.Modify(true);

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Partial receive should succeed');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(DocumentNo), 'A partial receive keeps the transfer order');
    end;

    local procedure JsonText(ResponseJson: JsonObject): Text
    var
        TextValue: Text;
    begin
        ResponseJson.WriteTo(TextValue);
        exit(TextValue);
    end;
}
